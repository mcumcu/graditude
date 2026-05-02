class CertificateProduct < ApplicationRecord
  belongs_to :cart
  belongs_to :certificate
  belongs_to :product
  belongs_to :stripe_price_map
  belongs_to :checkout_session, optional: true

  STATUSES = %w[pending purchased canceled].freeze

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :cart, :certificate, :product, :stripe_price_map, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validate :stripe_price_map_belongs_to_product

  def total_cents
    product.price_cents * quantity
  end

  private

  def stripe_price_map_belongs_to_product
    return if stripe_price_map.nil? || product.nil?

    unless stripe_price_map.product_id == product_id
      errors.add(:stripe_price_map, "must belong to the selected product")
    end
  end
end
