module Shipping
  module Providers
    class Stripe
      def initialize(client: nil)
        @client = client || ::Stripe::StripeClient.new(
          ENV["STRIPE_KEY"],
          stripe_version: ENV.fetch("STRIPE_API_VERSION", "2026-03-25.dahlia")
        )
      end

      def create_shipping_rate!(display_name:, amount_cents:, currency:, delivery_min_days: nil, delivery_max_days: nil, active: true, metadata: {})
        payload = build_payload(
          display_name: display_name,
          amount_cents: amount_cents,
          currency: currency,
          delivery_min_days: delivery_min_days,
          delivery_max_days: delivery_max_days,
          metadata: metadata
        )

        shipping_rate = @client.v1.shipping_rates.create(payload)
        if active == false
          shipping_rate = @client.v1.shipping_rates.update(shipping_rate.id, active: false)
        end
        Catalog::Normalizer.hashify(shipping_rate)
      end

      def update_shipping_rate!(shipping_rate_id, active: true, metadata: {})
        payload = {
          active: active,
          metadata: stringify_metadata(metadata)
        }.compact

        shipping_rate = @client.v1.shipping_rates.update(shipping_rate_id, payload)
        Catalog::Normalizer.hashify(shipping_rate)
      end

      def deactivate_shipping_rate!(shipping_rate_id)
        shipping_rate = @client.v1.shipping_rates.update(shipping_rate_id, active: false)
        Catalog::Normalizer.hashify(shipping_rate)
      end

      private

      def build_payload(display_name:, amount_cents:, currency:, delivery_min_days:, delivery_max_days:, metadata: {})
        payload = {
          display_name: display_name,
          type: "fixed_amount",
          fixed_amount: {
            amount: amount_cents,
            currency: currency
          },
          metadata: stringify_metadata(metadata)
        }

        estimate = delivery_estimate(delivery_min_days, delivery_max_days)
        payload[:delivery_estimate] = estimate if estimate.present?
        payload
      end

      def delivery_estimate(min_days, max_days)
        minimum = estimate_entry(min_days)
        maximum = estimate_entry(max_days)

        return nil if minimum.blank? && maximum.blank?

        { minimum: minimum, maximum: maximum }.compact
      end

      def estimate_entry(value)
        return nil if value.blank?

        {
          unit: "business_day",
          value: value.to_i
        }
      end

      def stringify_metadata(metadata)
        Catalog::Normalizer.hashify(metadata).transform_values { |value| value.to_s }
      end
    end
  end
end
