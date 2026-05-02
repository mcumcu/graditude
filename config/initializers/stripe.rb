stripe_secret_key = ENV["STRIPE_KEY"]
stripe_api_version = ENV.fetch("STRIPE_API_VERSION", "2026-03-25.dahlia")

if stripe_secret_key.present?
  Stripe.api_key = stripe_secret_key
  Stripe.api_version = stripe_api_version
end
