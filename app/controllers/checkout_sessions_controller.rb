class CheckoutSessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: %i[ create ]
  allow_unauthenticated_access only: %i[ create ]

  def new; end

  def show
    session = Stripe::Checkout::Session.retrieve(params[:session_id])

    {
      status: session.status,
      customer_email:  session.customer_details.email
    }.to_json
  end

  def create
    return_url = "#{request.protocol}#{request.host}:#{request.port}/checkout/{CHECKOUT_SESSION_ID}"

    params = {
      ui_mode: "embedded",
      line_items: [ {
        price: "price_1S7JZoBKCB1NBOVa2U4OXmFy",
        quantity: 1
      } ],
      mode: "payment",
      return_url: return_url
    }

    session = Stripe::Checkout::Session.create(params)

    render json: {
      clientSecret: session.client_secret
    }
  end
end
