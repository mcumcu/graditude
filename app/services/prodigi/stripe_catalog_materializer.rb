module Prodigi
  class StripeCatalogMaterializer
    def initialize(scope: ProdigiCatalogItem.all, phase: "materialize_stripe", dry_run: false)
      @scope = scope
      @phase = phase
      @dry_run = dry_run
      @product_provider = @dry_run ? DryRunStripeProvider.new : Catalog::Providers::Stripe.new
      @shipping_provider = @dry_run ? DryRunStripeProvider.new : Shipping::Providers::Stripe.new
      @stripe_product_ids = {}
      @stripe_shipping_rate_ids = {}
      @product_records = {}
    end

    def call!
      if @dry_run
        result = {
          processed: 0,
          skipped: 0,
          created: 0,
          updated: 0
        }

        ActiveRecord::Base.transaction do
          @scope.find_each do |item|
            next unless item.sku.present?

            result[:processed] += 1
            mapping = item.prodigi_stripe_mapping || item.build_prodigi_stripe_mapping
            was_new_record = mapping.new_record?
            product_record = product_record_for(item.product_family)
            stripe_price_id = create_or_update_price(item, product_record)
            stripe_shipping_rate_id = create_or_update_shipping_rate(item)

            mapping.update!(stripe_product_id: product_record.stripe_product_id,
                            stripe_price_id: stripe_price_id,
                            stripe_shipping_rate_id: stripe_shipping_rate_id,
                            variant_key: item.variant_key,
                            metadata: {
                              sku: item.sku,
                              destination_country: item.destination_country,
                              shipping_method: item.shipping_method,
                              product_family: item.product_family,
                              variant_name: item.formatted_variant_name
                            }.compact)

            result[was_new_record ? :created : :updated] += 1
          end

          raise ActiveRecord::Rollback
        end

        result
      else
        Prodigi::PipelineRunTracker.track(phase: @phase) do
          result = {
            processed: 0,
            skipped: 0,
            created: 0,
            updated: 0
          }

          @scope.find_each do |item|
            next unless item.sku.present?

            result[:processed] += 1
            mapping = item.prodigi_stripe_mapping || item.build_prodigi_stripe_mapping
            was_new_record = mapping.new_record?
            product_record = product_record_for(item.product_family)
            stripe_price_id = create_or_update_price(item, product_record)
            stripe_shipping_rate_id = create_or_update_shipping_rate(item)

            mapping.update!(stripe_product_id: product_record.stripe_product_id,
                            stripe_price_id: stripe_price_id,
                            stripe_shipping_rate_id: stripe_shipping_rate_id,
                            variant_key: item.variant_key,
                            metadata: {
                              sku: item.sku,
                              destination_country: item.destination_country,
                              shipping_method: item.shipping_method,
                              product_family: item.product_family,
                              variant_name: item.formatted_variant_name
                            }.compact)

            result[was_new_record ? :created : :updated] += 1
          end

          result
        end
      end
    end

    class DryRunStripeProvider
      def initialize
        @counts = Hash.new(0)
      end

      def create_product!(contract:, extra_product_data: {}, extra_metadata: {})
        id = "prod_dry_#{SecureRandom.hex(6)}"
        {
          "id" => id,
          "name" => contract[:heading],
          "description" => contract[:description],
          "metadata" => contract_metadata(contract, extra_metadata)
        }
      end

      def create_price!(product_id:, amount_cents:, currency:, metadata: {}, nickname: nil, active: true)
        id = "price_dry_#{SecureRandom.hex(6)}"
        {
          "id" => id,
          "product" => product_id,
          "unit_amount" => amount_cents,
          "currency" => currency,
          "nickname" => nickname,
          "metadata" => metadata.transform_values(&:to_s),
          "active" => active
        }
      end

      def create_shipping_rate!(display_name:, amount_cents:, currency:, delivery_min_days:, delivery_max_days:, metadata: {})
        id = "shr_dry_#{SecureRandom.hex(6)}"
        {
          "id" => id,
          "display_name" => display_name,
          "fixed_amount" => { "amount" => amount_cents, "currency" => currency },
          "delivery_estimate" => {
            "minimum" => { "unit" => "business_day", "value" => delivery_min_days },
            "maximum" => { "unit" => "business_day", "value" => delivery_max_days }
          },
          "metadata" => metadata.transform_values(&:to_s)
        }
      end

      def set_default_price!(product_id:, price_id:)
        {
          "id" => product_id,
          "default_price" => price_id,
          "metadata" => { "set_as_default" => "true" }
        }
      end

      private

      def contract_metadata(contract, extra_metadata)
        metadata = {
          "eyebrow" => contract[:eyebrow],
          "tagline" => contract[:tagline],
          "short_description" => contract[:short_description],
          "detail_intro" => contract[:detail_intro],
          "certificate_templates" => contract[:certificate_templates].join(", "),
          "format" => contract[:variant_format]
        }

        metadata.merge!(extra_metadata.stringify_keys)
        metadata.transform_values { |value| value.to_s }
      end
    end

    private

    def create_or_update_price(item, product_record)
      stripe_product_id = product_record.stripe_product_id
      return unless stripe_product_id.present? && item.product_price_amount_cents.present? && item.product_currency.present?
      existing_id = item.prodigi_stripe_mapping&.stripe_price_id
      return existing_id if existing_id.present?

      price = @product_provider.create_price!(
        product_id: stripe_product_id,
        amount_cents: item.product_price_amount_cents,
        currency: item.product_currency.downcase,
        nickname: item.formatted_variant_name.presence || "#{item.sku} variant",
        metadata: {
          prodigi_row_key: item.row_key,
          sku: item.sku,
          destination_country: item.destination_country,
          shipping_method: item.shipping_method,
          product_family: item.product_family,
          variant_key: item.variant_key
        }
      )

      price_id = price["id"]
      set_product_default_price_if_missing(product_record, price_id)
      price_record_for(product_record, price_id, price)

      price_id
    end
    def create_or_update_shipping_rate(item)
      return if item.shipping_method.blank? || item.shipping_price_cents.blank? || item.shipping_currency.blank?

      key = [ item.destination_country, item.shipping_method, item.shipping_currency, item.product_family ].map(&:to_s)
      return @stripe_shipping_rate_ids[key] if @stripe_shipping_rate_ids[key].present?

      rate = @shipping_provider.create_shipping_rate!(
        display_name: "#{item.shipping_method} (#{item.product_family.capitalize})",
        amount_cents: item.shipping_price_cents,
        currency: item.shipping_currency.downcase,
        delivery_min_days: item.minimum_shipping_days,
        delivery_max_days: item.maximum_shipping_days,
        metadata: {
          destination_country: item.destination_country,
          shipping_method: item.shipping_method,
          product_format: item.product_family,
          tracked_shipping: item.tracked_shipping
        }
      )
      @stripe_shipping_rate_ids[key] = rate["id"]
      rate["id"]
    end

    def product_id_for(product_family)
      @stripe_product_ids[product_family] ||= begin
        product = find_existing_product(product_family)
        return product if product.present?

        payload = contract_for(product_family)
        result = @product_provider.create_product!(contract: payload, extra_metadata: { prodigi_source: "pipeline" })
        result["id"]
      end
    end

    def product_record_for(product_family)
      @product_records[product_family] ||= begin
        stripe_product_id = product_id_for(product_family)
        product = Product.find_or_initialize_by(stripe_product_id: stripe_product_id)
        product.save! if product.new_record?

        stripe_product = retrieve_stripe_product(stripe_product_id, product_family)
        product.update_cached_stripe_product!(stripe_product)
        product
      end
    end

    def price_record_for(product, stripe_price_id, stripe_price_data = nil)
      price = product.prices.find_or_initialize_by(stripe_price_id: stripe_price_id)
      price.save! if price.new_record?
      price.update_cached_stripe_price!(stripe_price_data || retrieve_stripe_price(stripe_price_id))
      price
    end

    def set_product_default_price_if_missing(product_record, price_id)
      product_data = product_record.stripe_product_cache
      return if product_data.present? && product_data["default_price"].present?

      @product_provider.set_default_price!(product_id: product_record.stripe_product_id, price_id: price_id)
      product_record.update_cached_stripe_product!(retrieve_stripe_product(product_record.stripe_product_id, nil))
    rescue StandardError
      nil
    end

    def retrieve_stripe_product(stripe_product_id, product_family = nil)
      if @dry_run
        return dry_run_stripe_product(stripe_product_id, product_family)
      end

      product = Stripe::Product.retrieve(stripe_product_id)
      product = product.to_hash if product.respond_to?(:to_hash)
      Catalog::Normalizer.hashify(product)
    end

    def retrieve_stripe_price(stripe_price_id)
      if @dry_run
        return dry_run_stripe_price(stripe_price_id)
      end

      price = Stripe::Price.retrieve(stripe_price_id)
      price = price.to_hash if price.respond_to?(:to_hash)
      Catalog::Normalizer.hashify(price)
    end

    def dry_run_stripe_product(stripe_product_id, product_family)
      {
        "id" => stripe_product_id,
        "name" => product_family.to_s.capitalize.presence || "Prodigi Dry Run Product",
        "description" => "Dry-run stripe product payload for #{product_family || 'unknown'}.",
        "metadata" => {
          "format" => product_family.to_s,
          "certificate_templates" => ENV.fetch("DEFAULT_CERTIFICATE_TEMPLATE", "boulder"),
          "eyebrow" => "Graditude",
          "tagline" => "Printed and shipped via Prodigi",
          "short_description" => "High-quality Prodigi print production and shipping.",
          "detail_intro" => "Printed with Prodigi and delivered with tracked shipping."
        }
      }
    end

    def dry_run_stripe_price(stripe_price_id)
      {
        "id" => stripe_price_id,
        "unit_amount" => 1000,
        "currency" => "usd"
      }
    end

    def find_existing_product(product_family)
      Product.where("stripe_product_cache->'metadata'->>'format' = ?", product_family).limit(1).pluck(:stripe_product_id).first
    rescue ActiveRecord::StatementInvalid
      nil
    end

    def contract_for(product_family)
      name = product_family == "framed" ? "Graditude Framed Certificate" : "Graditude Printed Certificate"
      description = if product_family == "framed"
                      "Premium framed gratitude certificates fulfilled through Prodigi wall art products."
      else
                      "Premium printed gratitude certificates fulfilled through Prodigi prints and posters."
      end

      {
        heading: name,
        description: description,
        active: true,
        eyebrow: "Graditude",
        tagline: "Printed and shipped via Prodigi",
        short_description: "High-quality Prodigi print production and shipping.",
        detail_intro: "Printed with Prodigi and delivered with tracked shipping.",
        certificate_templates: [ ENV.fetch("DEFAULT_CERTIFICATE_TEMPLATE", "boulder") ],
        variant_format: product_family,
        attributes: [ "color", "frame", "paper_type", "size" ],
        marketing_features: [],
        images: []
      }
    end
  end
end
