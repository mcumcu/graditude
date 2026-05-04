class Product < ApplicationRecord
  has_many :certificate_products, dependent: :restrict_with_error
  has_many :stripe_price_maps, dependent: :destroy

  validates :title, presence: true

  def active_stripe_price_map
    stripe_price_maps.active.order(created_at: :desc).first
  end

  def stripe_price_map
    active_stripe_price_map
  end

  def stripe_price
    stripe_price_map&.stripe_price
  end

  def stripe_price_amount_cents
    stripe_price&.unit_amount
  end

  def stripe_price_currency
    stripe_price&.currency
  end

  def stripe_price_id
    stripe_price_map&.stripe_price_id
  end
end
