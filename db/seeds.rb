# This file should ensure the existence of records required to run the application in every environment.
# Data here is intentionally idempotent so it can be executed repeatedly with bin/rails db:seed.

initial_products = {
  "printed" => {
    stripe_product_id: "prod_URzyA1qvgEXtTG"
  },
  "framed" => {
    stripe_product_id: "prod_USIAUKjtQY3I1w"
  }
}

initial_products.each do |template, attrs|
  product = Product.find_or_initialize_by(stripe_product_id: attrs[:stripe_product_id])
  product.save!
  product.reload_stripe_product! # fetches the Stripe product payload immediately to populate stripe_product_cache and Rails cache
end
