module Shipping
  def self.provider
    @provider ||= Providers::Stripe.new
  end

  def self.provider=(provider)
    @provider = provider
  end
end
