# This file should ensure the existence of records required to run the application in every environment.
# Data here is intentionally idempotent so it can be executed repeatedly with bin/rails db:seed.

initial_products = {
  "boulder" => {
    title: "Boulder Graduation Certificate",
    description: "A presentation-ready certificate for graduates, custom designed and ready to gift.",
    price_cents: 3_000,
    currency: "USD",
    details: {
      colors: [ "navy", "gold" ],
      features: [
        "Professionally printed and framed",
        "Customized graduate and honoree names",
        "Authentic & licensed design"
      ],
      shippings: [ "US domestic standard shipping", "Expedited shipping available" ],
      returns: [ "Returns accepted within 30 days for damaged or incorrect orders." ],
      refunds: [ "Refunds issued after order review and approval." ],
      cancellations: [ "Cancel within 24 hours for full refund." ]
    },
    stripe_price_id: "price_1S7JZoBKCB1NBOVa2U4OXmFy"
  },
  "westtown" => {
    title: "Westtown Graduation Certificate",
    description: "A presentation-ready certificate for graduates, custom designed and ready to gift.",
    price_cents: 3_000,
    currency: "USD",
    details: {
      colors: [ "maroon", "cream" ],
      features: [
        "Professionally printed and framed",
        "Customized graduate and honoree names",
        "Authentic & licensed design"
      ],
      shippings: [ "US domestic standard shipping", "Expedited shipping available" ],
      returns: [ "Returns accepted within 30 days for damaged or incorrect orders." ],
      refunds: [ "Refunds issued after order review and approval." ],
      cancellations: [ "Cancel within 24 hours for full refund." ]
    },
    stripe_price_id: "price_1S7JZoBKCB1NBOVa2U4OXmFy"
  }
}

initial_products.each do |template, attrs|
  product = Product.find_or_initialize_by(title: attrs[:title])
  product.description = attrs[:description]
  product.price_cents = attrs[:price_cents]
  product.currency = attrs[:currency]
  product.details = attrs[:details]
  product.save!

  price_map = StripePriceMap.find_or_initialize_by(stripe_price_id: attrs[:stripe_price_id])
  price_map.product ||= product
  price_map.active = true
  price_map.save!
end
