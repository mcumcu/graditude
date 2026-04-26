class CheckoutSessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: %i[create]
  allow_unauthenticated_access only: %i[create new success cancel]

  TEMPLATE_PRICE_IDS = {
    "boulder" => "price_1S7JZoBKCB1NBOVa2U4OXmFy",
    "westtown" => "price_1S7JZoBKCB1NBOVa2U4OXmFy"
  }.freeze

  PRODUCTS = {
    TEMPLATE_PRICE_IDS["boulder"] => {
      name: "Graditude Certificate",
      description: "A presentation-ready gift for your special people.",
      image: "boulder.png",
      price_cents: 3_000,
      currency: "USD",
      features: [
        "Professionally printed and framed",
        "Customized graduate and honoree names",
        "Authentic & licensed design"
      ]
    },
    TEMPLATE_PRICE_IDS["westtown"] => {
      name: "Graditude Certificate",
      description: "A presentation-ready gift for your special people.",
      image: "westtown.png",
      price_cents: 3_000,
      currency: "USD",
      features: [
        "Professionally printed and framed",
        "Customized graduate and honoree names",
        "Authentic & licensed design"
      ]
    }
  }.freeze

  def new
    @certificate = certificate_for_checkout
    @price_id = params[:price_id].presence || (@certificate ? price_id_for_template(@certificate.template) : nil)
    @product = build_product_preview(@price_id, @certificate)
  end

  def create
    certificate = certificate_for_checkout
    price_id = params[:price_id].presence || (certificate ? price_id_for_template(certificate.template) : nil)
    unless price_id.present?
      return render json: { error: "missing price_id" }, status: :bad_request
    end

    session = Stripe::Checkout::Session.create(
      payment_method_types: [ "card" ],
      line_items: [
        {
          price: price_id,
          quantity: 1
        }
      ],
      mode: "payment",
      success_url: "#{request.base_url}#{checkout_success_path}",
      cancel_url: "#{request.base_url}#{checkout_cancel_path}"
    )

    render json: { sessionId: session.id }
  rescue Stripe::StripeError => error
    render json: { error: error.message }, status: :bad_gateway
  end

  def success; end

  def cancel; end

  private

  def price_id_for_template(template)
    TEMPLATE_PRICE_IDS[template.to_s.presence || ENV.fetch("DEFAULT_CERTIFICATE_TEMPLATE", "boulder")]
  end

  def certificate_for_checkout
    return unless params[:certificate_id].present?

    Certificate.find_by(id: params[:certificate_id])
  end

  def build_product_preview(price_id, certificate)
    product = PRODUCTS[price_id]&.dup
    return unless product

    if certificate
      template = certificate.template.presence || ENV.fetch("DEFAULT_CERTIFICATE_TEMPLATE", "boulder")
      product[:name] = "#{template.titleize} Graduation Certificate"
      product[:description] = if certificate.honoree_name.present?
        "A beautiful certificate for #{certificate.honoree_name}, personalized, framed, and ready to gift."
      else
        "A beautiful certificate, personalized, framed, and ready to gift."
      end
      product[:image] = preview_certificate_path(certificate, format: :png)
    end

    product
  end
end
