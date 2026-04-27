class CheckoutSessionReconciliationJob < ApplicationJob
  queue_as :default

  MAX_ATTEMPTS = 3

  def perform(checkout_session_id, attempt = 1)
    checkout_session = CheckoutSession.find_by(id: checkout_session_id)
    return unless checkout_session&.stripe_session_id.present?

    checkout_session.reconcile_status_from_stripe!

    if checkout_session.open? && attempt < MAX_ATTEMPTS
      self.class.set(wait: 1.minute).perform_later(checkout_session.id, attempt + 1)
    end
  rescue Stripe::StripeError => error
    checkout_session&.update(raw: checkout_session.raw_hash.deep_merge(reconciliation_error: error.message))
  end
end
