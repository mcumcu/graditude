module CertificatesHelper
  def formatted_stripe_price(product)
    price = product&.stripe_price
    return unless price

    number_to_currency(
      price.fetch("unit_amount", 0).to_i / 100.0,
      unit: currency_symbol(price.fetch("currency", "")),
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
    priced_products = Array(products).select { |product| product.stripe_price_amount_cents.present? }
    return "Pricing available at checkout" if priced_products.empty?

    cheapest = priced_products.min_by(&:stripe_price_amount_cents)
    formatted = formatted_stripe_price(cheapest)
    return "Pricing available at checkout" unless formatted.present?

    multiple_prices = priced_products.map(&:stripe_price_amount_cents).uniq.length > 1
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

    metadata = product.stripe_metadata.to_h.transform_keys { |key| key.to_s.downcase }
    value = metadata["format"] || metadata["framed"] || metadata["frame"]
    normalized = value.to_s.downcase

    return "framed" if %w[framed frame true yes 1].include?(normalized)
    return "unframed" if %w[unframed false no 0].include?(normalized)

    name = [ product.title, product.description ].compact.join(" ").downcase
    return "unframed" if name.include?("unframed") || name.include?("no frame")
    return "framed" if name.include?("framed") || name.include?("frame")

    nil
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
