class Product < ApplicationRecord
  has_many :certificate_products, dependent: :restrict_with_error

  validates :stripe_product_id, uniqueness: true, allow_blank: true

  STRIPE_PRODUCT_CACHE_EXPIRES_IN = 1.hour

  before_save :clear_previous_stripe_product_cache, if: :will_save_change_to_stripe_product_id?
  after_destroy :clear_stripe_product_cache!

  def stripe_product_cache
    self[:stripe_product_cache]
  end

  def stripe_product_data(reload: false)
    return unless stripe_product_id.present?

    if reload
      clear_stripe_product_cache!
      fetch_and_cache_stripe_product_data
    else
      Rails.cache.fetch(stripe_product_cache_key, expires_in: STRIPE_PRODUCT_CACHE_EXPIRES_IN, skip_nil: true) do
        stripe_product_cache.presence || fetch_and_cache_stripe_product_data
      end
    end
  end

  def stripe_product(reload: false)
    stripe_product_data(reload: reload)
  end

  def reload_stripe_product!
    stripe_product(reload: true)
  end

  def stripe_name
    stripe_product_data&.fetch("name", nil).presence
  end

  def stripe_description
    stripe_product_data&.fetch("description", nil).presence
  end

  def title
    stripe_name
  end

  def description
    stripe_description
  end

  def stripe_metadata
    stripe_product_data&.fetch("metadata", {}) || {}
  end

  def certificate_template_names
    stripe_metadata.fetch("certificate_templates", "").to_s.split(",").map(&:strip).reject(&:blank?)
  end

  def stripe_price(reload: false)
    return unless stripe_price_id.present?

    @stripe_price = nil if reload
    @stripe_price ||= Stripe::Price.retrieve(stripe_price_id)
  end

  def stripe_price_amount_cents
    stripe_price&.unit_amount
  end

  def stripe_price_currency
    stripe_price&.currency
  end

  def stripe_price_id
    stripe_product_data&.fetch("default_price", nil)
  end

  def update_cached_stripe_product!(stripe_product_hash)
    return unless stripe_product_hash.is_a?(Hash)

    cache_stripe_product_data(stripe_product_hash)
  end

  def clear_stripe_product_cache!
    Rails.cache.delete(stripe_product_cache_key) if stripe_product_id.present?
    update_column(:stripe_product_cache, {}) if persisted?
  end

  private

  def stripe_product_cache_key
    "stripe_product:#{stripe_product_id}"
  end

  def fetch_and_cache_stripe_product_data
    raw_product = Stripe::Product.retrieve(stripe_product_id).to_hash
    cache_stripe_product_data(raw_product)
    raw_product
  end

  def cache_stripe_product_data(raw_product)
    Rails.cache.write(stripe_product_cache_key, raw_product, expires_in: STRIPE_PRODUCT_CACHE_EXPIRES_IN)

    return unless persisted?

    update_column(:stripe_product_cache, raw_product)
  end

  def clear_previous_stripe_product_cache
    return unless stripe_product_id_in_database.present?

    Rails.cache.delete("stripe_product:#{stripe_product_id_in_database}")
    self.stripe_product_cache = {}
  end
end
