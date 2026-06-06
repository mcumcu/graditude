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

  def price_label_for(products)
    priced_products = Array(products).filter_map do |product|
      data = product&.catalog_data
      next unless data

      amount = data[:default_price_amount_cents]
      currency = data[:default_price_currency]
      next if amount.blank? || currency.blank?

      { amount: amount.to_i, currency: currency.to_s.upcase, product: product }
    end

    return "Pricing available at checkout" if priced_products.empty?

    unique_prices = priced_products.map { |entry| [ entry[:amount], entry[:currency] ] }.uniq
    return formatted_stripe_price(priced_products.first[:product]) if unique_prices.size == 1

    lowest_product = priced_products.min_by { |entry| entry[:amount] }[:product]
    "From #{formatted_stripe_price(lowest_product)}"
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

  def prodigi_color_swatch(color_label)
    case color_label.to_s.downcase
    when "black" then "#111827"
    when "white" then "#f8fafc"
    when "natural" then "#f3e9d2"
    when "beige" then "#e5d3b8"
    when "brown" then "#7c4c29"
    when "grey", "gray" then "#9ca3af"
    when "blue" then "#2563eb"
    when "green" then "#16a34a"
    when "red" then "#dc2626"
    else "#d1d5db"
    end
  end

  def formatted_prodigi_price(amount_cents, currency)
    currency ||= "USD"

    return "Pricing available" if amount_cents.blank? || currency.blank?

    number_to_currency(
      amount_cents.to_i / 100.0,
      unit: currency_symbol(currency),
      precision: 2
    )
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
    return false unless certificate

    certificate.purchased?
  end

  def product_in_cart?(product_id, certificate:)
    return false unless Current.user

    cart = Current.user.open_cart
    return false unless cart

    cart.certificate_products.exists?(product_id: product_id, certificate_id: certificate.id)
  end
end
