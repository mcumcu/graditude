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

    update!(status: new_status, raw: raw_hash.deep_merge(stripe_session: stripe_session.to_hash))
    complete_order! if new_status == "complete"
  end

  def complete_order!
    cart&.complete_order!(self)
  end
end
