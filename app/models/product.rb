class Product < ApplicationRecord
  has_many :certificate_products, dependent: :restrict_with_error
  has_many :stripe_price_maps, dependent: :destroy

  validates :title, presence: true, unless: :stripe_product_id?
  validates :stripe_product_id, uniqueness: true, allow_blank: true

  STRIPE_PRODUCT_CACHE_EXPIRES_IN = 1.hour

  before_save :clear_previous_stripe_product_cache, if: :will_save_change_to_stripe_product_id?
  after_destroy :clear_stripe_product_cache!

  def stripe_product_data(reload: false)
    return unless stripe_product_id.present?

    if reload
      clear_stripe_product_cache!
      fetch_and_cache_stripe_product_data
    else
      Rails.cache.fetch(stripe_product_cache_key, expires_in: STRIPE_PRODUCT_CACHE_EXPIRES_IN, skip_nil: true) do
        details.dig("stripe", "product").presence || fetch_and_cache_stripe_product_data
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
    stripe_product_data&.fetch("name", nil).presence || title
  end

  def stripe_description
    stripe_product_data&.fetch("description", nil).presence || description
  end

  def title
    stripe_product_data&.fetch("name", nil).presence || super
  end

  def description
    stripe_product_data&.fetch("description", nil).presence || super
  end

  def stripe_metadata
    stripe_product_data&.fetch("metadata", {}) || {}
  end

  def certificate_template_names
    stripe_metadata.fetch("certificate_templates", "").to_s.split(",").map(&:strip).reject(&:blank?)
  end

  def stripe_default_price
    price_reference = stripe_product_data&.fetch("default_price", nil)
    return unless price_reference.present?

    if price_reference.is_a?(String)
      Stripe::Price.retrieve(price_reference)
    else
      price_reference
    end
  end

  def active_stripe_price_map
    stripe_price_maps.active.order(created_at: :desc).first
  end

  def stripe_price_map
    active_stripe_price_map
  end

  def stripe_price
    stripe_default_price || stripe_price_map&.stripe_price
  end

  def stripe_price_amount_cents
    stripe_price&.unit_amount
  end

  def stripe_price_currency
    stripe_price&.currency
  end

  def stripe_price_id
    stripe_price&.id || stripe_price_map&.stripe_price_id
  end

  def update_cached_stripe_product!(stripe_product_hash)
    return unless stripe_product_hash.is_a?(Hash)

    cache_stripe_product_data(stripe_product_hash)
  end

  def clear_stripe_product_cache!
    Rails.cache.delete(stripe_product_cache_key) if stripe_product_id.present?
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

    cached_details = details.is_a?(Hash) ? details.deep_dup : {}
    cached_details["stripe"] ||= {}
    cached_details["stripe"]["product"] = raw_product
    cached_details["stripe"]["cached_at"] = Time.current.utc.iso8601
    update_column(:details, cached_details)
  end

  def clear_previous_stripe_product_cache
    return unless stripe_product_id_in_database.present?

    Rails.cache.delete("stripe_product:#{stripe_product_id_in_database}")
  end
end
