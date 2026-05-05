module CertificatesHelper
  PRODUCT_TITLE_BY_TEMPLATE = {
    "boulder" => "Boulder Graduation Certificate",
    "westtown" => "Westtown Graduation Certificate"
  }.freeze

  def checkout_price_id_for_template(template)
    product_for_template(template)&.stripe_price_id
  end

  def formatted_stripe_price(product)
    return unless product&.stripe_price

    number_to_currency(
      product.stripe_price.unit_amount / 100.0,
      unit: currency_symbol(product.stripe_price.currency),
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
    template_name = template.to_s.presence || ENV.fetch("DEFAULT_CERTIFICATE_TEMPLATE", "boulder")
    @product_for_template ||= {}
    @product_for_template[template_name] ||= begin
      products = Product.where.not(stripe_product_id: nil).to_a
      exact_match = products.find { |product| product.title == PRODUCT_TITLE_BY_TEMPLATE[template_name] }
      exact_match || products.sort_by { |product| product.title.to_s.downcase }
                             .find { |product| product.title.to_s.downcase.include?("#{template_name.titleize.downcase} graduation certificate") }
    end
  end

  def certificate_in_cart?(certificate)
    return false unless Current.user

    Current.user.open_cart&.certificate_products&.exists?(certificate_id: certificate.id)
  end
end
