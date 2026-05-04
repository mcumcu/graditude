module CertificatesHelper
  PRODUCT_TITLE_BY_TEMPLATE = {
    "boulder" => "Boulder Graduation Certificate",
    "westtown" => "Westtown Graduation Certificate"
  }.freeze

  def checkout_price_id_for_template(template)
    active_price_map_for_template(template)&.stripe_price_id
  end

  def active_price_map_for_template(template)
    product_for_template(template)&.active_stripe_price_map
  end

  def formatted_stripe_price(price_map)
    return unless price_map

    number_to_currency(
      price_map.unit_amount_cents / 100.0,
      unit: currency_symbol(price_map.currency),
      precision: 2
    )
  end

  def currency_symbol(currency)
    case currency.to_s.upcase
    when "USD" then "$"
    when "EUR" then "€"
    when "GBP" then "£"
    when "JPY" then "¥"
    else "#{currency&.upcase} " 
    end
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
