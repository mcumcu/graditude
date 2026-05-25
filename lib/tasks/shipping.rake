namespace :shipping do
  desc "Seed standard shipping rates from shipping-est.md"
  task seed_standard_rates: :environment do
    provider = Shipping.provider

    rates = [
      {
        display_name: "USPS Ground Advantage",
        product_format: "framed",
        billing_basis: "per_item",
        amount_cents: 1850,
        currency: "usd",
        delivery_min_days: 2,
        delivery_max_days: 5,
        default_rate: true
      },
      {
        display_name: "UPS Ground",
        product_format: "framed",
        billing_basis: "per_item",
        amount_cents: 1945,
        currency: "usd",
        delivery_min_days: 1,
        delivery_max_days: 5,
        default_rate: false
      },
      {
        display_name: "FedEx Home Delivery",
        product_format: "framed",
        billing_basis: "per_item",
        amount_cents: 2100,
        currency: "usd",
        delivery_min_days: 1,
        delivery_max_days: 5,
        default_rate: false
      },
      {
        display_name: "USPS Ground Advantage",
        product_format: "unframed",
        billing_basis: "per_order",
        amount_cents: 1050,
        currency: "usd",
        delivery_min_days: 2,
        delivery_max_days: 5,
        default_rate: true
      },
      {
        display_name: "USPS Priority Mail Flat Rate",
        product_format: "unframed",
        billing_basis: "per_order",
        amount_cents: 985,
        currency: "usd",
        delivery_min_days: 1,
        delivery_max_days: 3,
        default_rate: false
      },
      {
        display_name: "UPS Ground",
        product_format: "unframed",
        billing_basis: "per_order",
        amount_cents: 1600,
        currency: "usd",
        delivery_min_days: 1,
        delivery_max_days: 5,
        default_rate: false
      },
      {
        display_name: "FedEx Home Delivery",
        product_format: "unframed",
        billing_basis: "per_order",
        amount_cents: 1750,
        currency: "usd",
        delivery_min_days: 1,
        delivery_max_days: 5,
        default_rate: false
      }
    ]

    rates.each do |attrs|
      existing = ShippingRate.where(
        product_format: attrs[:product_format],
        billing_basis: attrs[:billing_basis]
      ).find do |rate|
        rate.stripe_display_name == attrs[:display_name]
      end

      if existing
        puts "Skipping #{attrs[:display_name]} (#{attrs[:product_format]}) - already exists."
        next
      end

      provider_rate = provider.create_shipping_rate!(
        display_name: attrs[:display_name],
        amount_cents: attrs[:amount_cents],
        currency: attrs[:currency],
        delivery_min_days: attrs[:delivery_min_days],
        delivery_max_days: attrs[:delivery_max_days],
        active: true,
        metadata: {
          product_format: attrs[:product_format],
          billing_basis: attrs[:billing_basis]
        }
      )

      record = ShippingRate.create!(
        stripe_shipping_rate_id: provider_rate.fetch("id"),
        stripe_shipping_rate_cache: provider_rate,
        product_format: attrs[:product_format],
        billing_basis: attrs[:billing_basis],
        active: true,
        default_rate: attrs[:default_rate]
      )

      if attrs[:default_rate]
        ShippingRate.where(product_format: attrs[:product_format])
          .where.not(id: record.id)
          .update_all(default_rate: false)
      end

      puts "Created #{attrs[:display_name]} (#{attrs[:product_format]})."
    end
  end
end
