class StripePriceMap < ApplicationRecord
  belongs_to :product

  scope :active, -> { where(active: true) }

  validates :stripe_price_id, presence: true, uniqueness: true
  validates :product, presence: true

  def stripe_price(reload: false)
    @stripe_price = nil if reload
    @stripe_price ||= Stripe::Price.retrieve(stripe_price_id)
  end

  def unit_amount_cents
    stripe_price.unit_amount
  end

  def currency
    stripe_price.currency
  end
end
