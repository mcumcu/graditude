module Catalog
  class Contract
    def self.from_stripe(product:, price:, with_defaults: true, infer_variant_format: true)
      product_hash = Normalizer.hashify(product)
      price_hash = Normalizer.hashify(price)
      metadata = Normalizer.hashify(product_hash["metadata"])

      heading = product_hash["name"].to_s.strip
      description = product_hash["description"].to_s
      description_paragraphs = Normalizer.paragraphs(description)

      eyebrow = metadata["eyebrow"].to_s.strip
      tagline = metadata["tagline"].to_s.strip
      short_description = metadata["short_description"].to_s.strip
      detail_intro = metadata["detail_intro"].to_s.strip
      attributes = Normalizer.normalize_attributes(product_hash["attributes"])
      marketing_features = Normalizer.normalize_marketing_features(product_hash["marketing_features"])
      certificate_templates = Normalizer.list_from_text(metadata["certificate_templates"])
      images = Normalizer.list_from_text(product_hash["images"])
      active = product_hash.key?("active") ? !!product_hash["active"] : true
      tax_code = product_hash["tax_code"].to_s.strip.presence

      variant_format = Normalizer.variant_format(
        metadata: metadata,
        heading: heading,
        description: description,
        infer: infer_variant_format
      )

      if with_defaults
        heading = Product::DEFAULT_HEADING if heading.blank?
        if description_paragraphs.empty?
          description_paragraphs = Product::DEFAULT_DESCRIPTION_PARAGRAPHS.dup
          description = description_paragraphs.join("\n\n")
        end

        eyebrow = eyebrow.presence || tagline.presence || Product::DEFAULT_EYEBROW
        short_description = short_description.presence || description_paragraphs.first.to_s
        short_description = Product::DEFAULT_SHORT_DESCRIPTION if short_description.blank?
        detail_intro = detail_intro.presence || Product::DEFAULT_DETAIL_INTRO
        marketing_features = Product::DEFAULT_MARKETING_FEATURES if marketing_features.empty?
      end

      default_price_id = price_hash["id"].presence || product_hash["default_price"].presence
      default_price_amount_cents = price_amount_cents(price_hash)
      default_price_currency = price_hash["currency"].to_s.presence

      {
        heading: heading,
        eyebrow: eyebrow,
        tagline: tagline.presence,
        description: description.presence,
        description_paragraphs: description_paragraphs,
        short_description: short_description.presence,
        detail_intro: detail_intro.presence,
        attributes: attributes,
        marketing_features: marketing_features,
        certificate_templates: certificate_templates,
        images: images,
        active: active,
        tax_code: tax_code,
        default_price_id: default_price_id,
        default_price_amount_cents: default_price_amount_cents,
        default_price_currency: default_price_currency,
        variant_format: variant_format
      }
    end

    def self.from_input(input)
      description_paragraphs = Normalizer.paragraphs(input[:description])

      {
        heading: input[:heading].to_s.strip,
        eyebrow: input[:eyebrow].to_s.strip,
        tagline: input[:tagline].to_s.strip,
        description: description_paragraphs.join("\n\n"),
        description_paragraphs: description_paragraphs,
        short_description: input[:short_description].to_s.strip,
        detail_intro: input[:detail_intro].to_s.strip,
        attributes: Normalizer.list_from_lines(input[:attributes]),
        marketing_features: Normalizer.marketing_features_from_text(input[:marketing_features]),
        certificate_templates: Normalizer.list_from_text(input[:certificate_templates]),
        images: Normalizer.list_from_text(input[:images]),
        active: ActiveModel::Type::Boolean.new.cast(input[:active]),
        tax_code: input[:tax_code].to_s.strip.presence,
        variant_format: input[:variant_format].to_s.strip.presence
      }
    end

    def self.price_amount_cents(price_hash)
      unit_amount = price_hash["unit_amount"]
      return unit_amount.to_i if unit_amount.present?

      decimal_amount = price_hash["unit_amount_decimal"]
      return nil if decimal_amount.blank?

      BigDecimal(decimal_amount.to_s).to_i
    end
  end
end
