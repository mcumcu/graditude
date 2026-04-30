class Product < ApplicationRecord
  has_many :certificate_products, dependent: :restrict_with_error
  has_many :stripe_price_maps, dependent: :destroy

  validates :title, presence: true
  validates :price_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :currency, presence: true
end
