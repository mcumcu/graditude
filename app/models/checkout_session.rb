class CheckoutSession < ApplicationRecord
  belongs_to :cart, optional: true
  has_many :checkout_session_certificates, dependent: :destroy
  has_many :certificates, through: :checkout_session_certificates
  has_many :certificate_products, dependent: :nullify

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
  end

  def expire_in_stripe!
    return unless stripe_session_id.present? && open?

    stripe_session = Stripe::Checkout::Session.expire(
      stripe_session_id,
      {},
      { idempotency_key: expire_idempotency_key }
    )

    update!(status: :expired, raw: raw_hash.deep_merge(stripe_session_expired: stripe_session.to_hash))
  end

  def expire_idempotency_key
    "checkout_session_expiration:#{id}"
  end

  private

  def build_shipping_details_payload(stripe_session)
    details = stripe_session.respond_to?(:shipping_details) ? stripe_session.shipping_details : stripe_session.to_hash["shipping_details"]
    return {} if details.blank?

    details = details.to_hash if details.respond_to?(:to_hash)
    details = details.to_h if details.respond_to?(:to_h)
    details = details.transform_keys(&:to_s) if details.respond_to?(:transform_keys)

    { "stripe_shipping_details" => details }
  end
end
