module Prodigi
  class StripeCatalogMaterializer
    def initialize(scope: ProdigiCatalogItem.all, phase: "materialize_stripe")
      @scope = scope
      @phase = phase
      @product_provider = Catalog::Providers::Stripe.new
      @shipping_provider = Shipping::Providers::Stripe.new
      @stripe_product_ids = {}
      @stripe_shipping_rate_ids = {}
    end

    def call!
      Prodigi::PipelineRunTracker.track(phase: @phase) do
        result = {
          processed: 0,
          skipped: 0,
          updated: 0
        }

        @scope.find_each do |item|
          next unless item.sku.present?

          result[:processed] += 1
          mapping = item.prodigi_stripe_mapping || item.build_prodigi_stripe_mapping
          was_new_record = mapping.new_record?
          stripe_product_id = product_id_for(item.product_family)
          stripe_price_id = create_or_update_price(item, stripe_product_id)
          stripe_shipping_rate_id = create_or_update_shipping_rate(item)

          mapping.update!(stripe_product_id: stripe_product_id,
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

    private

    def create_or_update_price(item, stripe_product_id)
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
        price["id"]
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
        slug = product_family.to_s.downcase
        product = find_existing_product(product_family)
        return product if product.present?

        payload = contract_for(product_family)
        result = @product_provider.create_product!(contract: payload, extra_metadata: { prodigi_source: "pipeline" })
        result["id"]
      end
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
