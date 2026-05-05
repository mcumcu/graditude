class CertificateProduct < ApplicationRecord
  belongs_to :cart
  belongs_to :certificate
  belongs_to :product
  belongs_to :checkout_session, optional: true

  STATUSES = %w[pending purchased canceled].freeze

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :cart, :certificate, :product, :stripe_price_id, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }

  def stripe_price(reload: false)
    product.prices.find_or_create_by!(stripe_price_id: stripe_price_id).stripe_price(reload: reload)
  end

  def unit_amount_cents
    stripe_price&.fetch("unit_amount", nil)
  end

  def currency
    stripe_price&.fetch("currency", nil)
  end

  def total_cents
    unit_amount_cents * quantity
  end
end
