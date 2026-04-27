class CheckoutSessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: %i[create]
  allow_unauthenticated_access only: %i[create new success cancel show]

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
    @certificate_ids = certificate_ids_param
    @price_id = params[:price_id].presence || (@certificate ? price_id_for_template(@certificate.template) : nil)
    @product = build_product_preview(@price_id, @certificate)
  end

  def create
    certificates = certificates_for_checkout
    items = if certificates.any?
      build_checkout_items(certificates)
    else
      price_id = params[:price_id].presence
      unless price_id.present?
        return render json: { error: "missing price_id" }, status: :bad_request
      end

      [ { price_id: price_id, quantity: 1 } ]
    end
    raw_payload = {
      request: {
        ip: request.remote_ip,
        user_agent: request.user_agent,
        params: checkout_create_params.to_h
      },
      items: items
    }

    checkout_session = CheckoutSession.create!(status: :open, items: items, raw: raw_payload)
    checkout_session.certificates << certificates if certificates.any?

    session = Stripe::Checkout::Session.create(
      payment_method_types: [ "card" ],
      line_items: items.map { |item| { price: item[:price_id], quantity: item[:quantity] } },
      mode: "payment",
      success_url: "#{request.base_url}#{checkout_success_path}?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: "#{request.base_url}#{checkout_cancel_path}",
      metadata: {
        checkout_session_id: checkout_session.id,
        certificate_ids: certificates.map(&:id).join(",")
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
    params.permit(:price_id, :certificate_id, :certificate_ids, certificate_ids: [])
  end

  def certificate_ids_param
    ids = params[:certificate_ids].presence || params[:certificate_id].presence
    Array.wrap(ids).flat_map { |value| value.to_s.split(",") }.map(&:strip).reject(&:blank?)
  end

  def certificates_for_checkout
    return Certificate.none if certificate_ids_param.blank?

    Certificate.where(id: certificate_ids_param)
  end

  def build_checkout_items(certificates)
    certificates.map do |certificate|
      {
        certificate_id: certificate.id,
        template: certificate.template.to_s.presence || ENV.fetch("DEFAULT_CERTIFICATE_TEMPLATE", "boulder"),
        price_id: price_id_for_template(certificate.template),
        quantity: 1
      }
    end
  end

  def price_id_for_template(template)
    TEMPLATE_PRICE_IDS[template.to_s.presence || ENV.fetch("DEFAULT_CERTIFICATE_TEMPLATE", "boulder")]
  end

  def certificate_for_checkout
    Certificate.find_by(id: certificate_ids_param.first)
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
