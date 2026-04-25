module CertificatesHelper
  PRICE_ID_BY_TEMPLATE = {
    "boulder" => "price_1S7JZoBKCB1NBOVa2U4OXmFy",
    "westtown" => "price_1S7JZoBKCB1NBOVa2U4OXmFz"
  }.freeze

  def checkout_price_id_for_template(template)
    PRICE_ID_BY_TEMPLATE[template.to_s.presence || ENV.fetch("DEFAULT_CERTIFICATE_TEMPLATE", "boulder")]
  end
end
