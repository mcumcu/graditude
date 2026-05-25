class CheckoutSessionsController < ApplicationController
  allow_unauthenticated_access only: %i[success cancel show]

  def new
    @cart = current_cart
  end

  def create
    cart = current_cart
    items = cart.checkout_items

    unless items.present?
      return render json: { error: "cart is empty" }, status: :bad_request
    end

    shipping_result = Shipping::Calculator.new(cart: cart).call
    shipping_details = shipping_result.details
    shipping_line_items = shipping_result.line_items

    raw_payload = {
      request: {
        ip: request.remote_ip,
        user_agent: request.user_agent,
        params: checkout_create_params.to_h
      },
      items: items,
      shipping: shipping_details
    }

    expire_existing_checkout_sessions(cart)
    checkout_session = CheckoutSession.create!(
      status: :open,
      cart: cart,
      items: items,
      raw: raw_payload,
      shipping_total_cents: shipping_result.total_cents,
      shipping_currency: shipping_result.currency,
      shipping_details: shipping_details
    )
    cart.certificate_products.update_all(checkout_session_id: checkout_session.id)

    line_items = items.map { |item| build_checkout_line_item(item) } + shipping_line_items
    session_params = {
      payment_method_types: checkout_payment_method_types,
      customer_email: Current.user.email_address,
      line_items: line_items,
      mode: "payment",
      billing_address_collection: "required",
      shipping_address_collection: { allowed_countries: checkout_shipping_countries },
      # automatic_tax: { enabled: true }, # Enable when Stripe tax calculation is configured, https://dashboard.stripe.com/test/settings/tax
      success_url: "#{request.base_url}#{checkout_success_path}?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: "#{request.base_url}#{checkout_cancel_path}?session_id={CHECKOUT_SESSION_ID}",
      metadata: {
        checkout_session_id: checkout_session.id,
        cart_id: cart.id
      }
      # shipping_options: [
      #   {
      #     shipping_rate: "shr_1TU55nBAkUp5qaORbGtZjdSN" # Free shipping option, configured in Stripe dashboard
      #   },
      #   {
      #     shipping_rate: "shr_1TT5vPBAkUp5qaORepowTn3R" # Ground shipping option, configured in Stripe dashboard
      #   },
      #   {
      #     shipping_rate: "shr_1TT5wCBAkUp5qaORNhlwDO5Y" # Express shipping option, configured in Stripe dashboard
      #   }
      # ]
    }
    session = stripe_client.v1.checkout.sessions.create(session_params)

    checkout_session.update!(stripe_session_id: session.id, raw: raw_payload.deep_merge(stripe_session: session.to_hash))
    CheckoutSessionReconciliationJob.set(wait: 1.minute).perform_later(checkout_session.id)

    render json: { sessionId: session.id, url: session.url }
  rescue Shipping::Calculator::MissingRateError, Shipping::Calculator::MissingFormatError, Shipping::Calculator::CurrencyMismatchError => error
    render json: { error: error.message }, status: :unprocessable_entity
  rescue Stripe::StripeError => error
    checkout_session&.update(status: :failed, raw: raw_payload.deep_merge(error: error.message))
    render json: { error: error.message }, status: :bad_gateway
  end

  def show
    checkout_session = CheckoutSession.find(params[:id])
    certificate_ids = checkout_session.certificate_products.distinct.pluck(:certificate_id)
    render json: checkout_session.as_json(
      only: [ :id, :status, :stripe_session_id, :items ]
    ).merge(
      certificate_ids: certificate_ids,
      created_at: checkout_session.created_at.iso8601,
      updated_at: checkout_session.updated_at.iso8601
    )
  end

  def success
    @session_id = params[:session_id]
    if @session_id.blank?
      redirect_to checkout_cancel_path
      return
    end

    checkout_session = CheckoutSession.find_by(stripe_session_id: @session_id)
    unless checkout_session
      redirect_to checkout_cancel_path
      return
    end

    begin
      checkout_session.reconcile_status_from_stripe! if checkout_session.open?
    rescue Stripe::StripeError => error
      checkout_session.append_raw(success_page_error: error.message)
    end

    @checkout_status = checkout_session.status
    return unless checkout_session.failed? || checkout_session.canceled? || checkout_session.expired?

    redirect_to checkout_cancel_path(session_id: @session_id, outcome: checkout_session.status)
  end

  def cancel
    @session_id = params[:session_id]
    @checkout_outcome = params[:outcome].presence
    return if @checkout_outcome.present?
    return if @session_id.blank?

    checkout_session = CheckoutSession.find_by(stripe_session_id: @session_id)
    @checkout_outcome = checkout_session&.status
  end

  private

  def checkout_create_params
    params.permit()
  end

  def checkout_payment_method_types
    configured_types = ENV.fetch("STRIPE_CHECKOUT_PAYMENT_METHOD_TYPES", "")
      .split(",")
      .map { |value| value.strip.downcase }
      .reject(&:blank?)
      .uniq

    configured_types.presence || [ "card" ]
  end

  def checkout_shipping_countries
    ENV.fetch("STRIPE_CHECKOUT_SHIPPING_COUNTRIES", "US,CA")
      .split(",")
      .map { |value| value.strip.upcase }
      .reject(&:blank?)
  end

  def checkout_shipping_options
    ENV.fetch("STRIPE_CHECKOUT_SHIPPING_RATE_IDS", "")
      .split(",")
      .map { |value| value.strip }
      .reject(&:blank?)
      .map { |shipping_rate| { shipping_rate: shipping_rate } }
  end

  def stripe_client
    Stripe::StripeClient.new(
      ENV["STRIPE_KEY"],
      stripe_version: ENV.fetch("STRIPE_API_VERSION", "2026-03-25.dahlia")
    )
  end

  def build_checkout_line_item(item)
    if item[:price_id].present?
      stripe_price = Price.find_or_create_by!(stripe_price_id: item[:price_id]).stripe_price_data
      product = Product.find(item[:product_id])
      product_data = (product.stripe_product_data || {}).slice(
        "name",
        "description",
        "metadata",
        "tax_code",
        "images"
      ).compact
      product_data["images"] = [ checkout_item_image_url(item[:certificate_template]) ]

      price_data = stripe_price.slice(
        "currency",
        "recurring",
        "tax_behavior"
      ).compact

      if stripe_price["unit_amount_decimal"].present?
        price_data["unit_amount_decimal"] = stripe_price["unit_amount_decimal"]
      elsif stripe_price["unit_amount"].present?
        price_data["unit_amount"] = stripe_price["unit_amount"]
      end

      {
        price_data: price_data.deep_symbolize_keys.merge(
          product_data: product_data.deep_symbolize_keys
        ),
        quantity: item[:quantity]
      }
    else
      # this branch should be deprecated in favor of pre-configured Stripe Price IDs
      {
        price_data: {
          currency: item[:currency],
          unit_amount: item[:unit_amount],
          product_data: {
            name: item[:product_title],
            description: item[:product_description],
            images: [ checkout_item_image_url(item[:certificate_template]) ]
          }
        },
        quantity: item[:quantity]
      }
    end
  end

  def checkout_item_image_url(template)
    template_name = template.presence || ENV.fetch("DEFAULT_CERTIFICATE_TEMPLATE", "boulder")
    "#{request.base_url}#{view_context.asset_path("#{template_name}.png")}".gsub(%r{([^:])/+}, '\1/')
  end

  def expire_existing_checkout_sessions(cart)
    cart.checkout_sessions.open.where.not(stripe_session_id: nil).find_each do |checkout_session|
      checkout_session.expire_in_stripe!
    end
  end

  def current_cart
    Cart.open_for(Current.user)
  end
end
