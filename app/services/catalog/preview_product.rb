module Catalog
  class PreviewProduct
    def self.from_input(input, fallback_product: nil)
      contract = build_contract(input, fallback_product: fallback_product)
      new(contract)
    end

    def initialize(contract)
      @contract = contract
    end

    def catalog_data(*_args, **_kwargs)
      @contract
    end

    def id
      @id ||= "preview"
    end

    def display_name
      @contract[:heading]
    end

    def display_eyebrow
      @contract[:eyebrow]
    end

    def display_description_paragraphs
      @contract[:description_paragraphs]
    end

    def display_description
      @contract[:description]
    end

    def display_short_description
      @contract[:short_description]
    end

    def display_detail_intro
      @contract[:detail_intro]
    end

    def display_attributes
      @contract[:attributes]
    end

    def display_marketing_features
      @contract[:marketing_features]
    end

    def certificate_template_names
      @contract[:certificate_templates]
    end

    def variant_format
      @contract[:variant_format]
    end

    def self.build_contract(input, fallback_product: nil)
      base = Catalog::Contract.from_input(
        heading: input[:name],
        eyebrow: input[:eyebrow],
        tagline: input[:tagline],
        description: input[:description],
        short_description: input[:short_description],
        detail_intro: input[:detail_intro],
        attributes: input[:attributes_text],
        marketing_features: input[:marketing_features_text],
        certificate_templates: input[:certificate_templates_text],
        images: input[:images_text],
        active: input[:active],
        tax_code: input[:tax_code],
        variant_format: input[:variant_format]
      )

      price_amount_cents, currency = preview_price(input, fallback_product)

      product_hash = {
        "name" => base[:heading],
        "description" => base[:description],
        "attributes" => base[:attributes],
        "marketing_features" => base[:marketing_features],
        "images" => base[:images],
        "active" => base[:active],
        "tax_code" => base[:tax_code],
        "metadata" => {
          "eyebrow" => base[:eyebrow],
          "tagline" => base[:tagline],
          "short_description" => base[:short_description],
          "detail_intro" => base[:detail_intro],
          "certificate_templates" => base[:certificate_templates].join(", "),
          "format" => base[:variant_format]
        }
      }

      price_hash = {}
      price_hash["unit_amount"] = price_amount_cents if price_amount_cents.present?
      price_hash["currency"] = currency if currency.present?

      Catalog::Contract.from_stripe(
        product: product_hash,
        price: price_hash,
        with_defaults: true,
        infer_variant_format: true
      )
    end

    def self.preview_price(input, fallback_product)
      currency = input[:currency].to_s.strip.presence
      price_amount_cents = parse_price_amount(input[:price_amount])

      return [ price_amount_cents, currency ] if price_amount_cents.present? || currency.present?
      return [ nil, nil ] unless fallback_product

      fallback = fallback_product.catalog_data
      [ fallback[:default_price_amount_cents], fallback[:default_price_currency] ]
    end

    def self.parse_price_amount(value)
      return nil if value.blank?

      (BigDecimal(value.to_s).round(2) * 100).to_i
    rescue ArgumentError
      nil
    end

    private_class_method :build_contract, :preview_price, :parse_price_amount
  end
end
