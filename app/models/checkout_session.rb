class CheckoutSession < ApplicationRecord
  belongs_to :cart, optional: true
  has_one :order, dependent: :destroy
  has_many :certificate_products, dependent: :nullify

  after_update_commit :broadcast_order_update_if_needed

  enum :status, {
    open: "open",
    complete: "complete",
    canceled: "canceled",
    expired: "expired",
    failed: "failed"
  }

  validates :stripe_session_id, uniqueness: true, allow_nil: true

  def raw_hash
    raw.presence || {}
  end

  def shipping_details_hash
    shipping_details.presence || {}
  end

  def append_raw(payload)
    update!(raw: raw_hash.deep_merge(payload))
  end

  def reconcile_status_from_stripe!
    return unless stripe_session_id.present?

    stripe_session = Stripe::Checkout::Session.retrieve(stripe_session_id)
    stripe_status = stripe_session.status
    new_status = if stripe_status == "complete"
                   "complete"
    elsif stripe_status == "expired"
                   "expired"
    elsif stripe_status == "canceled"
                   "canceled"
    elsif stripe_session.payment_status == "paid"
                   "complete"
    else
                   "open"
    end

    shipping_payload = build_shipping_details_payload(stripe_session)

    update!(
      status: new_status,
      raw: raw_hash.deep_merge(stripe_session: stripe_session.to_hash),
      shipping_details: shipping_details_hash.deep_merge(shipping_payload)
    )
    complete_order! if new_status == "complete"
  end

  def complete_order!
    cart&.complete_order!(self)
    ensure_order!
  end

  def ensure_order!
    return order if order.present?
    return unless complete?
    return unless cart&.user.present?

    order_attributes = {
      user: cart.user,
      status: :order_placed,
      raw: order_snapshot_payload,
      shipping_address: order_shipping_address_payload
    }

    Order.find_or_create_by!(checkout_session: self) do |record|
      record.assign_attributes(order_attributes)
    end.tap do |record|
      merged_raw = record.raw_hash.deep_merge(order_snapshot_payload)
      updates = {}
      updates[:user] = cart&.user if record.user_id != cart&.user_id
      updates[:raw] = merged_raw if record.raw_hash != merged_raw

      shipping_address = order_shipping_address_payload
      if shipping_address.present? && record.shipping_address_hash != shipping_address
        updates[:shipping_address] = shipping_address
      end

      next if updates.empty?

      record.update!(updates)
    end
  end

  def expire_in_stripe!
    return unless stripe_session_id.present? && open?

    stripe_session = Stripe::Checkout::Session.expire(
      stripe_session_id,
      {},
      { idempotency_key: expire_idempotency_key }
    )

    update!(status: :expired, raw: raw_hash.deep_merge(stripe_session_expired: stripe_session.to_hash))
  rescue Stripe::InvalidRequestError => error
    if expire_conflict_error?(error)
      append_raw(expiration_error: error.message)
      reconcile_status_from_stripe!
    else
      raise
    end
  end

  def expire_idempotency_key
    "checkout_session_expiration:#{id}"
  end

  private

  def broadcast_order_update_if_needed
    return unless order.present?
    return if (saved_changes.keys & %w[status raw shipping_details items shipping_total_cents shipping_currency stripe_session_id]).empty?

    sync_order_shipping_address!
    Orders::Broadcasts.order_updated(order.reload)
  end

  def order_snapshot_payload
    payload = {
      "checkout_session" => {
        "id" => id,
        "status" => status,
        "stripe_session_id" => stripe_session_id
      }
    }

    payload["stripe_session"] = raw_hash["stripe_session"] if raw_hash["stripe_session"].present?
    payload
  end

  def order_shipping_address_payload
    shipping_details = normalized_address_details(
      shipping_details_hash["stripe_shipping_details"] ||
      shipping_details_hash[:stripe_shipping_details] ||
      raw_hash.dig("stripe_session", "shipping_details")
    )
    return shipping_details.merge("source" => "stripe_shipping_details") if shipping_details.present?

    customer_details = normalized_address_details(raw_hash.dig("stripe_session", "customer_details"))
    return customer_details.merge("source" => "stripe_customer_details") if customer_details.present?

    {}
  end

  def sync_order_shipping_address!
    shipping_address = order_shipping_address_payload
    return if shipping_address.blank?
    return if order.shipping_address_hash == shipping_address

    order.update_columns(shipping_address: shipping_address, updated_at: Time.current)
  end

  def normalized_address_details(details)
    return {} if details.blank?

    details = details.to_hash if details.respond_to?(:to_hash)
    details = details.to_h if details.respond_to?(:to_h)
    details = details.transform_keys(&:to_s) if details.respond_to?(:transform_keys)

    address = details["address"]
    address = address.to_hash if address.respond_to?(:to_hash)
    address = address.to_h if address.respond_to?(:to_h)
    address = address.transform_keys(&:to_s) if address.respond_to?(:transform_keys)

    payload = {
      "name" => details["name"],
      "phone" => details["phone"],
      "address" => address.presence
    }.compact

    payload.compact_blank
  end

  def expire_conflict_error?(error)
    message = error.message.to_s
    return false unless message.include?("Only Checkout Sessions with a status in")

    status = message.match(/status of `(?<status>\w+)`/)&.[](:status)
    status.present? && status != "open"
  end

  def build_shipping_details_payload(stripe_session)
    details = stripe_session.respond_to?(:shipping_details) ? stripe_session.shipping_details : stripe_session.to_hash["shipping_details"]
    return {} if details.blank?

    details = details.to_hash if details.respond_to?(:to_hash)
    details = details.to_h if details.respond_to?(:to_h)
    details = details.transform_keys(&:to_s) if details.respond_to?(:transform_keys)

    { "stripe_shipping_details" => details }
  end
end
