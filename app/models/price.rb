class Price < ApplicationRecord
  belongs_to :product

  STRIPE_PRICE_CACHE_EXPIRES_IN = 1.hour

  validates :stripe_price_id, presence: true, uniqueness: true

  before_save :clear_previous_stripe_price_cache, if: :will_save_change_to_stripe_price_id?
  after_destroy :clear_stripe_price_cache!

  def stripe_price_cache
    self[:stripe_price_cache]
  end

  def stripe_price_data(reload: false)
    return unless stripe_price_id.present?

    if reload
      clear_stripe_price_cache!
      fetch_and_cache_stripe_price_data
    else
      Rails.cache.fetch(stripe_price_cache_key, expires_in: STRIPE_PRICE_CACHE_EXPIRES_IN, skip_nil: true) do
        stripe_price_cache.presence || fetch_and_cache_stripe_price_data
      end
    end
  end

  def stripe_price(reload: false)
    stripe_price_data(reload: reload)
  end

  def stripe_price_amount_cents
    stripe_price&.fetch("unit_amount", nil)
  end

  def stripe_price_currency
    stripe_price_data&.fetch("currency", nil)
  end

  def clear_stripe_price_cache!
    Rails.cache.delete(stripe_price_cache_key) if stripe_price_id.present?
    update_column(:stripe_price_cache, {}) if persisted?
  end

  private

  def stripe_price_cache_key
    "stripe_price:#{stripe_price_id}"
  end

  def fetch_and_cache_stripe_price_data
    raw_price = Stripe::Price.retrieve(stripe_price_id)
    raw_price = raw_price.to_hash if raw_price.respond_to?(:to_hash)
    raw_price = raw_price.to_h if raw_price.respond_to?(:to_h)
    raw_price = raw_price.transform_keys(&:to_s) if raw_price.respond_to?(:transform_keys)
    cache_stripe_price_data(raw_price)
    raw_price
  end

  def cache_stripe_price_data(raw_price)
    Rails.cache.write(stripe_price_cache_key, raw_price, expires_in: STRIPE_PRICE_CACHE_EXPIRES_IN)

    return unless persisted?

    update_column(:stripe_price_cache, raw_price)
  end

  def clear_previous_stripe_price_cache
    return unless stripe_price_id_in_database.present?

    Rails.cache.delete("stripe_price:#{stripe_price_id_in_database}")
    self.stripe_price_cache = {}
  end
end
