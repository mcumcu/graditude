class CheckoutSessionExpirationJob < ApplicationJob
  queue_as :default

  MAX_ATTEMPTS = 3

  def perform(checkout_session_id, attempt = 1)
    checkout_session = CheckoutSession.find_by(id: checkout_session_id)
    return unless checkout_session&.stripe_session_id.present?
    return unless checkout_session.open?

    checkout_session.expire_in_stripe!
  rescue Stripe::StripeError => error
    checkout_session&.append_raw(expiration_error: error.message)

    if attempt < MAX_ATTEMPTS
      self.class.set(wait: 1.minute).perform_later(checkout_session_id, attempt + 1)
    end
  end
end
