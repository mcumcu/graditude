if ENV["STRIPE_KEY"].present?
  Stripe.api_key = ENV["STRIPE_KEY"]
end
