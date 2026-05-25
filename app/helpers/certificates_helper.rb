module CertificatesHelper
  def formatted_stripe_price(product)
    data = product&.catalog_data
    return unless data

    amount = data[:default_price_amount_cents]
    currency = data[:default_price_currency]
    return if amount.blank? || currency.blank?

    number_to_currency(
      amount.to_i / 100.0,
      unit: currency_symbol(currency),
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

  def price_label_for(products)
    priced_products = Array(products).select { |product| product.catalog_data[:default_price_amount_cents].present? }
    return "Pricing available at checkout" if priced_products.empty?

    cheapest = priced_products.min_by { |product| product.catalog_data[:default_price_amount_cents].to_i }
    formatted = formatted_stripe_price(cheapest)
    return "Pricing available at checkout" unless formatted.present?

    multiple_prices = priced_products.map { |product| product.catalog_data[:default_price_amount_cents].to_i }.uniq.length > 1
    multiple_prices ? "From #{formatted}" : formatted
  end

  def product_variant_label(product)
    format = product_variant_format(product)
    return "Framed" if format == "framed"
    return "Unframed" if format == "unframed"

    "Certificate"
  end

  def product_variant_format(product)
    return if product.nil?

    product.variant_format
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

  def certificate_purchased?(certificate)
    return false unless Current.user

    certificate.certificate_products.where(status: "purchased").exists?
  end

  def product_in_cart?(product_id, certificate:)
    return false unless Current.user

    cart = Current.user.open_cart
    return false unless cart

    cart.certificate_products.exists?(product_id: product_id, certificate_id: certificate.id)
  end
end
