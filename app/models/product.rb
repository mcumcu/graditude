class Product < ApplicationRecord
  has_many :certificate_products, dependent: :restrict_with_error
  has_many :prices, dependent: :destroy

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
    default_price&.stripe_price(reload: reload)
  end

  def stripe_price_amount_cents
    default_price&.stripe_price_amount_cents
  end

  def stripe_price_currency
    default_price&.stripe_price_currency
  end

  def stripe_price_id
    stripe_product_data&.fetch("default_price", nil)
  end

  def default_price
    return unless stripe_price_id.present?

    prices.find_or_create_by!(stripe_price_id: stripe_price_id)
  end

  def self.for_certificate_template(template)
    template_name = template.to_s.presence || ENV.fetch("DEFAULT_CERTIFICATE_TEMPLATE", "boulder")
    where.not(stripe_product_id: nil).to_a
         .select { |product| product.certificate_template_names.map(&:downcase).include?(template_name.downcase) }
         .sort_by { |product| -product.stripe_price_amount_cents.to_i }
  end

  def update_cached_stripe_product!(stripe_product_hash)
    return unless stripe_product_hash.is_a?(Hash)

    cache_stripe_product_data(stripe_product_hash)
  end

  def clear_stripe_product_cache!
    old_price_id = stripe_price_id
    Rails.cache.delete(stripe_product_cache_key) if stripe_product_id.present?
    update_column(:stripe_product_cache, {}) if persisted?
    clear_cached_price_for_stripe_price(old_price_id)
  end

  private

  def clear_cached_price_for_stripe_price(stripe_price_id)
    return unless stripe_price_id.present?

    prices.where(stripe_price_id: stripe_price_id).find_each(&:clear_stripe_price_cache!)
  end

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

    clear_cached_price_for_stripe_price(stripe_price_id)
    Rails.cache.delete("stripe_product:#{stripe_product_id_in_database}")
    self.stripe_product_cache = {}
  end
end
