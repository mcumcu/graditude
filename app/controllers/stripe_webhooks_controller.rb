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
    when "payment_intent.canceled", "charge.refunded", "charge.dispute.created", "charge.dispute.closed"
      handle_order_event(event)
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

    shipping_payload = shipping_details_payload(session)
    checkout_session.update(
      status: new_status,
      raw: checkout_session.raw.to_h.deep_merge(
        "stripe_event" => event.to_hash,
        "stripe_session" => session.to_hash
      ),
      shipping_details: (checkout_session.shipping_details.presence || {}).deep_merge(shipping_payload)
    )

    checkout_session.complete_order! if new_status == "complete"
  end

  def handle_order_event(event)
    order = order_for_stripe_object(event.data.object, event_type: event.type)
    return unless order

    order.append_raw(
      "stripe_events" => {
        event.type => event.to_hash
      }
    )
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

  def shipping_details_payload(session)
    details = session.respond_to?(:shipping_details) ? session.shipping_details : session.to_hash["shipping_details"]
    return {} if details.blank?

    details = details.to_hash if details.respond_to?(:to_hash)
    details = details.to_h if details.respond_to?(:to_h)
    details = details.transform_keys(&:to_s) if details.respond_to?(:transform_keys)

    { "stripe_shipping_details" => details }
  end

  def order_for_stripe_object(stripe_object, event_type:)
    object_hash = stripe_object_hash(stripe_object)

    checkout_session_id = object_hash.dig("metadata", "checkout_session_id")
    if checkout_session_id.present?
      order = Order.find_by(checkout_session_id: checkout_session_id)
      return order if order
    end

    payment_intent_id = payment_intent_id_for(object_hash, event_type: event_type)
    if payment_intent_id.present?
      order = Order.includes(:checkout_session).detect do |candidate|
        candidate.raw_hash.dig("stripe_session", "payment_intent") == payment_intent_id ||
          candidate.checkout_session.raw_hash.dig("stripe_session", "payment_intent") == payment_intent_id
      end
      return order if order
    end

    charge_id = charge_id_for(object_hash, event_type: event_type)
    return if charge_id.blank?

    Order.includes(:checkout_session).detect do |candidate|
      candidate.raw_hash.dig("stripe_session", "charge") == charge_id ||
        candidate.checkout_session.raw_hash.dig("stripe_session", "charge") == charge_id
    end
  end

  def stripe_object_hash(stripe_object)
    object_hash = stripe_object.respond_to?(:to_hash) ? stripe_object.to_hash : stripe_object.to_h
    object_hash.transform_keys(&:to_s)
  end

  def payment_intent_id_for(object_hash, event_type:)
    return object_hash["id"] if event_type.start_with?("payment_intent.")

    value = object_hash["payment_intent"]
    return value if value.is_a?(String)
    return value["id"] if value.is_a?(Hash)

    nil
  end

  def charge_id_for(object_hash, event_type:)
    return object_hash["id"] if event_type.start_with?("charge.")

    value = object_hash["charge"]
    return value if value.is_a?(String)
    return value["id"] if value.is_a?(Hash)

    nil
  end
end
