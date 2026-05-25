module Shipping
  class Calculator
    class MissingRateError < StandardError; end
    class MissingFormatError < StandardError; end
    class CurrencyMismatchError < StandardError; end

    Result = Struct.new(:line_items, :details, :total_cents, :currency, keyword_init: true)

    def initialize(cart:, framed_rate: nil, unframed_rate: nil)
      @cart = cart
      @framed_rate = framed_rate
      @unframed_rate = unframed_rate
    end

    def call
      counts = format_counts

      rates = {
        "framed" => rate_for_format("framed", counts["framed"]),
        "unframed" => rate_for_format("unframed", counts["unframed"])
      }.compact

      line_items = []
      rate_details = []
      total_cents = 0
      currency = nil

      rates.each do |format, rate|
        quantity = quantity_for(rate, counts[format])
        next if quantity <= 0

        amount_cents = rate.stripe_amount_cents
        raise MissingRateError, "Missing shipping rate amount for #{format}." if amount_cents.blank?

        rate_currency = rate.stripe_currency.to_s.downcase
        raise MissingRateError, "Missing shipping rate currency for #{format}." if rate_currency.blank?
        currency ||= rate_currency
        if currency.present? && rate_currency.present? && rate_currency != currency
          raise CurrencyMismatchError, "Shipping rates must share the same currency."
        end

        line_items << build_line_item(rate, format, quantity, amount_cents, rate_currency)
        total_cents += amount_cents.to_i * quantity

        rate_details << {
          shipping_rate_id: rate.id,
          stripe_shipping_rate_id: rate.stripe_shipping_rate_id,
          display_name: rate.stripe_display_name,
          product_format: format,
          billing_basis: rate.billing_basis,
          quantity: quantity,
          unit_amount_cents: amount_cents.to_i,
          total_cents: amount_cents.to_i * quantity,
          currency: rate_currency,
          delivery_estimate: rate.delivery_estimate
        }
      end

      Result.new(
        line_items: line_items,
        details: {
          counts: counts,
          rates: rate_details
        },
        total_cents: total_cents,
        currency: currency
      )
    end

    private

    def format_counts
      counts = { "framed" => 0, "unframed" => 0 }

      @cart.certificate_products.includes(:product).each do |item|
        format = item.product.variant_format.to_s.downcase
        raise MissingFormatError, "Missing product format for shipping." if format.blank?
        raise MissingFormatError, "Unsupported product format: #{format}." unless ShippingRate::FORMATS.include?(format)

        if format == "framed"
          counts["framed"] += item.quantity
        else
          counts["unframed"] += item.quantity
        end
      end

      counts
    end

    def rate_for_format(format, count)
      return nil if count.to_i <= 0

      rate = format == "framed" ? @framed_rate : @unframed_rate
      rate ||= ShippingRate.default_for_format(format)
      raise MissingRateError, "No active #{format} shipping rate configured." unless rate

      rate
    end

    def quantity_for(rate, count)
      return 0 if count.to_i <= 0

      rate.billing_basis == "per_item" ? count.to_i : 1
    end

    def build_line_item(rate, format, quantity, amount_cents, currency)
      display_name = rate.stripe_display_name || "Shipping"
      name = format == "framed" ? "#{display_name} (Framed shipping)" : "#{display_name} (Print shipping)"

      product_data = {
        name: name,
        metadata: {
          shipping_rate_id: rate.id,
          stripe_shipping_rate_id: rate.stripe_shipping_rate_id,
          product_format: format,
          billing_basis: rate.billing_basis
        }
      }

      description = rate.delivery_window_label
      product_data[:description] = description if description.present?

      {
        price_data: {
          currency: currency,
          unit_amount: amount_cents.to_i,
          product_data: product_data
        },
        quantity: quantity
      }
    end
  end
end
