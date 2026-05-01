module CertificatesHelper
  PRICE_ID_BY_TEMPLATE = {
    "boulder" => "price_1S7JZoBKCB1NBOVa2U4OXmFy",
    "westtown" => "price_1S7JZoBKCB1NBOVa2U4OXmFy"
  }.freeze

  PRODUCT_TITLE_BY_TEMPLATE = {
    "boulder" => "Boulder Graduation Certificate",
    "westtown" => "Westtown Graduation Certificate"
  }.freeze

  def checkout_price_id_for_template(template)
    PRICE_ID_BY_TEMPLATE[template.to_s.presence || ENV.fetch("DEFAULT_CERTIFICATE_TEMPLATE", "boulder")]
  end

  def add_to_cart_product_id_for_template(template)
    product_for_template(template)&.id
  end

  def product_for_template(template)
    Product.find_by(title: PRODUCT_TITLE_BY_TEMPLATE[template.to_s.presence || ENV.fetch("DEFAULT_CERTIFICATE_TEMPLATE", "boulder")])
  end

  def certificate_in_cart?(certificate)
    return false unless Current.user

    Current.user.open_cart&.certificate_products&.exists?(certificate_id: certificate.id)
  end
end
