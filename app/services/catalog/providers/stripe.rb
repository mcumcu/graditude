module Catalog
  module Providers
    class Stripe
      EXTRA_PRODUCT_KEYS = %w[
        statement_descriptor
        shippable
        package_dimensions
        unit_label
        url
        metadata
      ].freeze

      def initialize(client: nil)
        @client = client || ::Stripe::StripeClient.new(
          ENV["STRIPE_KEY"],
          stripe_version: ENV.fetch("STRIPE_API_VERSION", "2026-03-25.dahlia")
        )
      end

      def create_product!(contract:, extra_product_data: {}, extra_metadata: {})
        payload = build_product_payload(contract, extra_product_data, extra_metadata)
        product = @client.v1.products.create(payload)
        Normalizer.hashify(product)
      end

      def update_product!(product_id, contract:, extra_product_data: {}, extra_metadata: {})
        payload = build_product_payload(contract, extra_product_data, extra_metadata)
        product = @client.v1.products.update(product_id, payload)
        Normalizer.hashify(product)
      end

      def archive_product!(product_id, fallback_cache: {})
        deleted = @client.v1.products.delete(product_id)
        deleted_hash = Normalizer.hashify(deleted)
        return fallback_cache.merge("id" => product_id, "active" => false, "deleted" => true) if deleted_hash["deleted"]

        deleted_hash
      rescue ::Stripe::StripeError
        product = @client.v1.products.update(product_id, active: false)
        Normalizer.hashify(product)
      end

      def create_price!(product_id:, amount_cents:, currency:)
        payload = {
          product: product_id,
          unit_amount: amount_cents,
          currency: currency
        }

        price = @client.v1.prices.create(payload)
        Normalizer.hashify(price)
      end

      def set_default_price!(product_id:, price_id:)
        product = @client.v1.products.update(product_id, default_price: price_id)
        Normalizer.hashify(product)
      end

      private

      def build_product_payload(contract, extra_product_data, extra_metadata)
        metadata = {
          "eyebrow" => contract[:eyebrow],
          "tagline" => contract[:tagline],
          "short_description" => contract[:short_description],
          "detail_intro" => contract[:detail_intro],
          "certificate_templates" => contract[:certificate_templates].join(", "),
          "format" => contract[:variant_format]
        }

        metadata.merge!(stringify_metadata(extra_metadata))
        metadata = metadata.transform_values { |value| value.to_s }

        base_payload = {
          name: contract[:heading],
          description: contract[:description],
          active: contract[:active],
          images: contract[:images],
          tax_code: contract[:tax_code],
          attributes: contract[:attributes],
          marketing_features: contract[:marketing_features],
          metadata: metadata
        }

        extra_product = filter_extra_product_data(extra_product_data)
        extra_metadata_from_product = extra_product.delete("metadata") || extra_product.delete(:metadata)
        if extra_metadata_from_product.present?
          base_payload[:metadata] = base_payload[:metadata].merge(stringify_metadata(extra_metadata_from_product))
        end

        base_payload.merge(extra_product).compact
      end

      def filter_extra_product_data(extra_product_data)
        data = Normalizer.hashify(extra_product_data)
        data.select { |key, _value| EXTRA_PRODUCT_KEYS.include?(key.to_s) }
      end

      def stringify_metadata(metadata)
        Normalizer.hashify(metadata).transform_values { |value| value.to_s }
      end
    end
  end
end
