class StripeWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  allow_unauthenticated_access only: :receive

  def receive
    payload = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    event = Stripe::Webhook.construct_event(payload, sig_header, ENV.fetch("STRIPE_WEBHOOK_SECRET"))

    handle_event(event)
    head :ok
  rescue JSON::ParserError, Stripe::SignatureVerificationError => error
    render json: { error: error.message }, status: :bad_request
  end

  private

  def handle_event(event)
    session = event.data.object
    checkout_session = CheckoutSession.find_by(stripe_session_id: session.id)
    return unless checkout_session

    checkout_session.update(
      status: status_for(event.type),
      raw: checkout_session.raw.to_h.deep_merge(
        "stripe_event" => event.to_hash,
        "stripe_session" => session.to_hash
      )
    )
  end

  def status_for(event_type)
    case event_type
    when "checkout.session.completed"
      "complete"
    when "checkout.session.expired"
      "expired"
    when "checkout.session.async_payment_failed"
      "failed"
    when "checkout.session.canceled"
      "canceled"
    else
      "open"
    end
  end
end
