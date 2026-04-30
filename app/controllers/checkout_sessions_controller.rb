class CheckoutSessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: %i[create]
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

    raw_payload = {
      request: {
        ip: request.remote_ip,
        user_agent: request.user_agent,
        params: checkout_create_params.to_h
      },
      items: items
    }

    checkout_session = CheckoutSession.create!(status: :open, cart: cart, items: items, raw: raw_payload)
    cart.certificate_products.update_all(checkout_session_id: checkout_session.id)

    session = Stripe::Checkout::Session.create(
      payment_method_types: [ "card" ],
      line_items: items.map { |item| { price: item[:price_id], quantity: item[:quantity] } },
      mode: "payment",
      success_url: "#{request.base_url}#{checkout_success_path}?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: "#{request.base_url}#{checkout_cancel_path}",
      metadata: {
        checkout_session_id: checkout_session.id,
        cart_id: cart.id
      }
    )

    checkout_session.update!(stripe_session_id: session.id, raw: raw_payload.deep_merge(stripe_session: session.to_hash))
    CheckoutSessionReconciliationJob.set(wait: 1.minute).perform_later(checkout_session.id)

    render json: { sessionId: session.id }
  rescue Stripe::StripeError => error
    checkout_session&.update(status: :failed, raw: raw_payload.deep_merge(error: error.message))
    render json: { error: error.message }, status: :bad_gateway
  end

  def show
    checkout_session = CheckoutSession.find(params[:id])
    render json: checkout_session.as_json(
      only: [ :id, :status, :stripe_session_id, :items ],
      methods: [ :certificate_ids ]
    ).merge(
      created_at: checkout_session.created_at.iso8601,
      updated_at: checkout_session.updated_at.iso8601
    )
  end

  def success
    @session_id = params[:session_id]
  end

  def cancel
  end

  private

  def checkout_create_params
    params.permit()
  end

  def current_cart
    Cart.open_for(Current.user)
  end
end
