class StripePriceMap < ApplicationRecord
  belongs_to :product

  validates :stripe_price_id, presence: true, uniqueness: true
  validates :product, presence: true
end
