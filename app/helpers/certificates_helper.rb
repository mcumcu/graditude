module CertificatesHelper
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

  def products_for_template(template)
    template_name = template.to_s.presence || ENV.fetch("DEFAULT_CERTIFICATE_TEMPLATE", "boulder")
    @products_for_template ||= {}
    @products_for_template[template_name] ||= begin
      products = Product.where.not(stripe_product_id: nil).to_a
      products.select { |product| product.certificate_template_names.map(&:downcase).include?(template_name.downcase) }
              .sort_by { |product| product.title.to_s.downcase }
    end
  end

  def certificate_in_cart?(certificate)
    return false unless Current.user

    cart = Current.user.open_cart
    return false unless cart

    cart.certificate_products.exists?(certificate_id: certificate.id)
  end

  def product_in_cart?(product_id, certificate:)
    return false unless Current.user

    cart = Current.user.open_cart
    return false unless cart

    cart.certificate_products.exists?(product_id: product_id, certificate_id: certificate.id)
  end
end
