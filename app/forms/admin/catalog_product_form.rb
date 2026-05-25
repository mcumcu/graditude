module Admin
  class CatalogProductForm
    include ActiveModel::Model
    include ActiveModel::Attributes

    attr_accessor :product

    attribute :name, :string
    attribute :eyebrow, :string
    attribute :tagline, :string
    attribute :description, :string
    attribute :short_description, :string
    attribute :detail_intro, :string
    attribute :attributes_text, :string
    attribute :marketing_features_text, :string
    attribute :certificate_templates_text, :string
    attribute :images_text, :string
    attribute :variant_format, :string
    attribute :active, :boolean, default: true
    attribute :tax_code, :string
    attribute :price_amount, :string
    attribute :currency, :string, default: "usd"
    attribute :extra_metadata_json, :string
    attribute :extra_product_json, :string

    validates :name, presence: true
    validate :validate_price
    validate :validate_json_fields

    def self.from_product(product)
      data = product.catalog_data(with_defaults: false, infer_variant_format: false)

      new(
        product: product,
        name: data[:heading],
        eyebrow: data[:eyebrow],
        tagline: data[:tagline],
        description: data[:description_paragraphs].join("\n\n"),
        short_description: data[:short_description],
        detail_intro: data[:detail_intro],
        attributes_text: data[:attributes].join("\n"),
        marketing_features_text: format_marketing_features(data[:marketing_features]),
        certificate_templates_text: data[:certificate_templates].join(", "),
        images_text: data[:images].join("\n"),
        variant_format: data[:variant_format],
        active: data[:active].nil? ? true : data[:active],
        tax_code: data[:tax_code],
        price_amount: format_price_amount(data[:default_price_amount_cents]),
        currency: data[:default_price_currency] || "usd"
      )
    end

    def self.format_price_amount(amount_cents)
      return nil if amount_cents.blank?

      format("%.2f", amount_cents.to_f / 100.0)
    end

    def self.format_marketing_features(features)
      Array(features).map do |feature|
        name = feature["name"] || feature[:name]
        description = feature["description"] || feature[:description]

        if description.present?
          "#{name} | #{description}"
        else
          name
        end
      end.compact.join("\n")
    end

    private_class_method :format_price_amount, :format_marketing_features

    def save
      return false unless valid?

      provider = ::Catalog.provider
      contract = ::Catalog::Contract.from_input(contract_input)

      if product.present?
        update_product(provider, contract)
      else
        create_product(provider, contract)
      end
    end

    def archive
      return false unless product.present?

      provider = ::Catalog.provider
      product_data = provider.archive_product!(product.stripe_product_id, fallback_cache: product.stripe_product_cache)
      product.update_cached_stripe_product!(product_data)
      true
    rescue Stripe::StripeError => error
      errors.add(:base, error.message)
      false
    end

    private

    def contract_input
      {
        heading: name,
        eyebrow: eyebrow,
        tagline: tagline,
        description: description,
        short_description: short_description,
        detail_intro: detail_intro,
        attributes: attributes_text,
        marketing_features: marketing_features_text,
        certificate_templates: certificate_templates_text,
        images: images_text,
        active: active,
        tax_code: tax_code,
        variant_format: variant_format
      }
    end

    def create_product(provider, contract)
      provider_product = provider.create_product!(
        contract: contract,
        extra_product_data: parsed_extra_product,
        extra_metadata: parsed_extra_metadata
      )

      provider_price = provider.create_price!(
        product_id: provider_product.fetch("id"),
        amount_cents: price_amount_cents,
        currency: currency.to_s.downcase
      )

      provider_product = provider.set_default_price!(
        product_id: provider_product.fetch("id"),
        price_id: provider_price.fetch("id")
      )

      self.product = Product.create!(
        stripe_product_id: provider_product.fetch("id"),
        stripe_product_cache: provider_product
      )

      product.update_cached_stripe_product!(provider_product)
      price_record = product.prices.find_or_create_by!(stripe_price_id: provider_price.fetch("id"))
      price_record.update_cached_stripe_price!(provider_price)
      true
    rescue Stripe::StripeError, ActiveRecord::RecordInvalid => error
      errors.add(:base, error.message)
      false
    end

    def update_product(provider, contract)
      provider_product = provider.update_product!(
        product.stripe_product_id,
        contract: contract,
        extra_product_data: parsed_extra_product,
        extra_metadata: parsed_extra_metadata
      )

      if price_changed?
        provider_price = provider.create_price!(
          product_id: product.stripe_product_id,
          amount_cents: price_amount_cents,
          currency: currency.to_s.downcase
        )

        provider_product = provider.set_default_price!(
          product_id: product.stripe_product_id,
          price_id: provider_price.fetch("id")
        )

        price_record = product.prices.find_or_create_by!(stripe_price_id: provider_price.fetch("id"))
        price_record.update_cached_stripe_price!(provider_price)
      end

      product.update_cached_stripe_product!(provider_product)
      true
    rescue Stripe::StripeError, ActiveRecord::RecordInvalid => error
      errors.add(:base, error.message)
      false
    end

    def price_changed?
      return false if price_amount_cents.nil?
      return true unless product

      current_amount = product.stripe_price_amount_cents
      current_currency = product.stripe_price_currency
      return true if current_amount.blank? || current_currency.blank?

      current_amount.to_i != price_amount_cents || current_currency.to_s.downcase != currency.to_s.downcase
    end

    def price_amount_cents
      return nil if price_amount.blank?

      (BigDecimal(price_amount.to_s).round(2) * 100).to_i
    rescue ArgumentError
      nil
    end

    def validate_price
      cents = price_amount_cents

      if product.nil? && cents.nil?
        errors.add(:price_amount, "is required")
        return
      end

      if price_amount.present? && cents.nil?
        errors.add(:price_amount, "must be a valid number")
      end

      if price_amount.present? && currency.to_s.strip.blank?
        errors.add(:currency, "is required when setting a price")
      end
    end

    def validate_json_fields
      parsed_extra_metadata
      parsed_extra_product
    end

    def parsed_extra_metadata
      return {} if extra_metadata_json.blank?
      return @parsed_extra_metadata if defined?(@parsed_extra_metadata)

      data = JSON.parse(extra_metadata_json)
      unless data.is_a?(Hash)
        errors.add(:extra_metadata_json, "must be a JSON object")
        data = {}
      end

      @parsed_extra_metadata = data
    rescue JSON::ParserError
      errors.add(:extra_metadata_json, "must be valid JSON")
      @parsed_extra_metadata = {}
    end

    def parsed_extra_product
      return {} if extra_product_json.blank?
      return @parsed_extra_product if defined?(@parsed_extra_product)

      data = JSON.parse(extra_product_json)
      unless data.is_a?(Hash)
        errors.add(:extra_product_json, "must be a JSON object")
        return @parsed_extra_product = {}
      end

      invalid_keys = data.keys.map(&:to_s) - ::Catalog::Providers::Stripe::EXTRA_PRODUCT_KEYS
      if invalid_keys.any?
        errors.add(:extra_product_json, "has unsupported keys: #{invalid_keys.join(", ")}")
        return @parsed_extra_product = {}
      end

      @parsed_extra_product = data
    rescue JSON::ParserError
      errors.add(:extra_product_json, "must be valid JSON")
      @parsed_extra_product = {}
    end
  end
end
