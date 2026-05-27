class CheckoutSessionsController < ApplicationController
  include Printable

  allow_unauthenticated_access only: %i[success cancel show preview_image]

  def new
    @cart = current_cart
  end

  def create
    cart = current_cart
    items = cart.checkout_items

    unless items.present?
      return render json: { error: "cart is empty" }, status: :bad_request
    end

    selected_rates = selected_shipping_rates(checkout_create_params[:shipping_rate_ids])
    shipping_result = Shipping::Calculator.new(cart: cart, **selected_rates).call
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

    line_items = items.map { |item| build_checkout_line_item(item, checkout_session: checkout_session) } + shipping_line_items
    session_params = {
      payment_method_types: checkout_payment_method_types,
      customer_email: Current.user.email_address,
      line_items: line_items,
      mode: "payment",
      billing_address_collection: "required",
      shipping_address_collection: { allowed_countries: checkout_shipping_countries },
      # automatic_tax: { enabled: true }, # Enable when Stripe tax calculation is configured, https://dashboard.stripe.com/test/settings/tax
      success_url: checkout_success_url(public_app_url_options.merge(session_id: "{CHECKOUT_SESSION_ID}")),
      cancel_url: cart_url(public_app_url_options),
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

  def preview_image
    preview_request = verified_checkout_preview_request(params[:token])
    return head :not_found unless preview_request

    checkout_session = CheckoutSession.find_by(id: preview_request[:checkout_session_id], status: :open)
    return head :not_found unless checkout_session

    png_data = checkout_preview_png_data(preview_request[:template])
    return head :not_found unless png_data.present?

    response.headers["Cache-Control"] = "private, no-store"
    send_data png_data, type: "image/png", disposition: "inline"
  end

  private

  def checkout_create_params
    params.permit(shipping_rate_ids: {})
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

  def selected_shipping_rates(selected_rate_ids)
    rate_ids = selected_rate_ids.to_h

    framed_rate = selected_shipping_rate_for("framed", rate_ids)
    unframed_rate = selected_shipping_rate_for("unframed", rate_ids)

    { framed_rate: framed_rate, unframed_rate: unframed_rate }.compact
  end

  def selected_shipping_rate_for(format, rate_ids)
    rate_id = rate_ids[format] || rate_ids[format.to_sym]
    return nil if rate_id.blank?

    rate = ShippingRate.active.for_format(format).find_by(id: rate_id)
    raise Shipping::Calculator::MissingRateError, "Selected shipping option is no longer available." unless rate

    rate
  end

  def build_checkout_line_item(item, checkout_session:)
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
      checkout_image_url = checkout_item_image_url(checkout_session: checkout_session, template: item[:certificate_template])
      if checkout_image_url.present?
        product_data["images"] = [ checkout_image_url ]
      elsif product_data["images"].blank?
        product_data.delete("images")
      end

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
      checkout_image_url = checkout_item_image_url(checkout_session: checkout_session, template: item[:certificate_template])
      product_data = {
        name: item[:product_title],
        description: item[:product_description]
      }
      product_data[:images] = [ checkout_image_url ] if checkout_image_url.present?

      {
        price_data: {
          currency: item[:currency],
          unit_amount: item[:unit_amount],
          product_data: product_data
        },
        quantity: item[:quantity]
      }
    end
  end

  def checkout_item_image_url(checkout_session:, template:)
    template_name = normalized_checkout_template(template)
    checkout_preview_image_url(checkout_session: checkout_session, template: template_name) || checkout_default_image_url
  end

  def checkout_preview_image_url(checkout_session:, template:)
    token = checkout_preview_token(checkout_session: checkout_session, template: template)
    checkout_preview_url(public_app_url_options.merge(token: token))
  rescue StandardError
    nil
  end

  def normalized_checkout_template(template)
    template_name = template.to_s.strip.presence
    return template_name if Certificate::TEMPLATE_VALUES.include?(template_name)

    default_template = ENV.fetch("DEFAULT_CERTIFICATE_TEMPLATE", "boulder").to_s.strip
    return default_template if Certificate::TEMPLATE_VALUES.include?(default_template)

    "boulder"
  end

  def checkout_default_image_url
    url = ENV["CHECKOUT_DEFAULT_IMAGE_URL"].to_s.strip
    return nil if url.blank?

    return url if url.match?(%r{\Ahttps?://}i)

    nil
  end

  def expire_existing_checkout_sessions(cart)
    cart.checkout_sessions.open.where.not(stripe_session_id: nil).find_each do |checkout_session|
      checkout_session.expire_in_stripe!
    end
  end

  def checkout_preview_png_data(template)
    template_name = normalized_checkout_template(template)

    Rails.cache.fetch(checkout_preview_cache_key(template_name), expires_in: 12.hours, skip_nil: true) do
      png_path = blank_certificate_png_path(template_name, resize_to: checkout_preview_resize_to)
      next unless png_path.present? && File.exist?(png_path)

      File.binread(png_path)
    end
  rescue StandardError
    nil
  end

  def checkout_preview_cache_key(template_name)
    [ "checkout_preview_image", "v1", template_name, checkout_preview_resize_to ].join(":")
  end

  def checkout_preview_resize_to
    "384"
  end

  def checkout_preview_token(checkout_session:, template:)
    checkout_preview_verifier.generate(
      {
        checkout_session_id: checkout_session.id,
        template: template
      },
      expires_in: 1.day,
      purpose: :checkout_preview
    )
  end

  def verified_checkout_preview_request(token)
    payload = checkout_preview_verifier.verified(token.to_s, purpose: :checkout_preview)
    return unless payload.is_a?(Hash)

    request_data = payload.with_indifferent_access
    template_name = normalized_checkout_template(request_data[:template])
    return unless template_name == request_data[:template].to_s

    request_data[:template] = template_name
    request_data
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageVerifier::InvalidMessage
    nil
  end

  def checkout_preview_verifier
    Rails.application.message_verifier(:checkout_preview)
  end

  def public_app_url_options
    configured_options = Rails.application.config.action_mailer.default_url_options.to_h.symbolize_keys.compact
    return {} if configured_options[:host].blank?

    configured_options[:protocol] ||= request.protocol.delete_suffix("://")
    configured_options.slice(:host, :protocol, :port)
  end

  def current_cart
    Cart.open_for(Current.user)
  end
end
