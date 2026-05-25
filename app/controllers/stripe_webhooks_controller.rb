class StripeWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  allow_unauthenticated_access only: :receive

  def receive
    payload = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    event = Stripe::Webhook.construct_event(payload, sig_header, ENV.fetch("STRIPE_WEBHOOK_SECRET"))

    handle_event(event)
    head :ok
  rescue JSON::ParserError => error
    render json: { error: error.message }, status: :bad_request
  rescue Stripe::SignatureVerificationError
    head :ok
  end

  private

  def handle_event(event)
    case event.type
    when "product.created", "product.updated"
      handle_product_event(event.data.object)
    when "product.deleted"
      handle_deleted_product_event(event.data.object)
    when "price.created", "price.updated"
      handle_price_event(event.data.object)
    when "price.deleted"
      handle_deleted_price_event(event.data.object)
    else
      handle_checkout_event(event)
    end
  end

  def handle_product_event(product_object)
    product = Product.find_by(stripe_product_id: product_object.id)
    return unless product

    product.update_cached_stripe_product!(product_object.to_hash)
    Catalog::Broadcasts.product_updated(product)
  end

  def handle_deleted_product_event(product_object)
    product = Product.find_by(stripe_product_id: product_object.id)
    return unless product

    product.clear_stripe_product_cache!
    Catalog::Broadcasts.product_updated(product)
  end

  def handle_price_event(price_object)
    price_hash = price_object.to_hash
    price = Price.find_by(stripe_price_id: price_object.id)
    product = price&.product

    if price.nil?
      product ||= Product.find_by(stripe_product_id: price_object.product)
      price = product&.prices&.find_or_create_by!(stripe_price_id: price_object.id)
    end

    product&.clear_stripe_product_cache!
    price&.update_cached_stripe_price!(price_hash)
    Catalog::Broadcasts.product_updated(product) if product
  end

  def handle_deleted_price_event(price_object)
    price = Price.find_by(stripe_price_id: price_object.id)
    product = price&.product || Product.find_by(stripe_product_id: price_object.product)

    price&.clear_stripe_price_cache!
    product&.clear_stripe_product_cache!
    Catalog::Broadcasts.product_updated(product) if product
  end

  def handle_checkout_event(event)
    session = event.data.object
    checkout_session = CheckoutSession.find_by(stripe_session_id: session.id)
    return unless checkout_session

    new_status = status_for(event.type)
    return unless new_status.present?

    checkout_session.update(
      status: new_status,
      raw: checkout_session.raw.to_h.deep_merge(
        "stripe_event" => event.to_hash,
        "stripe_session" => session.to_hash
      )
    )

    checkout_session.complete_order! if new_status == "complete"
  end

  def status_for(event_type)
    case event_type
    when "checkout.session.completed"
      "complete"
    when "checkout.session.async_payment_succeeded"
      "complete"
    when "checkout.session.expired"
      "expired"
    when "checkout.session.async_payment_failed"
      "failed"
    else
      nil
    end
  end
end
