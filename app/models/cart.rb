class Cart < ApplicationRecord
  belongs_to :user
  has_many :certificate_products, dependent: :destroy
  has_many :products, through: :certificate_products
  has_many :checkout_sessions, dependent: :nullify

  STATUSES = %w[open completed canceled].freeze

  validates :user, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  def open?
    status == "open"
  end

  def completed?
    status == "completed"
  end

  def self.open_for(user)
    user.open_cart || user.create_open_cart!
  end

  def checkout_items
    certificate_products.includes(:product, :stripe_price_map).map do |item|
      {
        certificate_product_id: item.id,
        product_id: item.product_id,
        certificate_id: item.certificate_id,
        price_id: item.stripe_price_map.stripe_price_id,
        quantity: item.quantity
      }
    end
  end

  def total_cents
    certificate_products.includes(:product).sum { |item| item.product.price_cents * item.quantity }
  end

  def complete_order!(checkout_session)
    transaction do
      update!(status: :completed)
      certificate_products.pending.update_all(status: "purchased", checkout_session_id: checkout_session.id)
    end
  end
end
