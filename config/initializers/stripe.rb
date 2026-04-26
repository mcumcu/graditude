stripe_secret_key = ENV["STRIPE_KEY"]

if stripe_secret_key.present?
  Stripe.api_key = stripe_secret_key
end
