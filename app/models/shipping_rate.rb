class ShippingRate < ApplicationRecord
  STRIPE_SHIPPING_RATE_CACHE_EXPIRES_IN = 1.hour
  FORMATS = %w[framed unframed].freeze
  BILLING_BASIS = %w[per_item per_order].freeze

  validates :stripe_shipping_rate_id, presence: true, uniqueness: true
  validates :product_format, presence: true, inclusion: { in: FORMATS }
  validates :billing_basis, presence: true, inclusion: { in: BILLING_BASIS }
  validates :active, inclusion: { in: [ true, false ] }
  validates :default_rate, inclusion: { in: [ true, false ] }

  before_save :clear_previous_stripe_shipping_rate_cache, if: :will_save_change_to_stripe_shipping_rate_id?
  after_destroy :clear_stripe_shipping_rate_cache!
  after_destroy_commit :broadcast_rate_removed

  scope :active, -> { where(active: true) }
  scope :for_format, ->(format) { where(product_format: format) }
  scope :defaults, -> { where(default_rate: true) }

  def self.default_for_format(format)
    active.for_format(format).order(default_rate: :desc, updated_at: :desc).first
  end

  def stripe_shipping_rate_cache
    self[:stripe_shipping_rate_cache]
  end

  def stripe_shipping_rate_data(reload: false)
    return unless stripe_shipping_rate_id.present?

    if reload
      clear_stripe_shipping_rate_cache!
      fetch_and_cache_stripe_shipping_rate_data
    else
      Rails.cache.fetch(stripe_shipping_rate_cache_key, expires_in: STRIPE_SHIPPING_RATE_CACHE_EXPIRES_IN, skip_nil: true) do
        stripe_shipping_rate_cache.presence || fetch_and_cache_stripe_shipping_rate_data
      end
    end
  end

  def stripe_display_name
    stripe_shipping_rate_data&.fetch("display_name", nil)
  end

  def stripe_amount_cents
    stripe_shipping_rate_data&.dig("fixed_amount", "amount")
  end

  def stripe_currency
    stripe_shipping_rate_data&.dig("fixed_amount", "currency")
  end

  def delivery_estimate
    stripe_shipping_rate_data&.fetch("delivery_estimate", nil)
  end

  def delivery_window_label
    estimate = delivery_estimate || {}
    min = estimate.dig("minimum", "value")
    max = estimate.dig("maximum", "value")
    unit = estimate.dig("minimum", "unit") || estimate.dig("maximum", "unit")

    return nil if min.blank? && max.blank?

    unit_label = unit == "business_day" ? "Business Days" : unit.to_s.tr("_", " ").titleize
    if min.present? && max.present?
      "#{min}-#{max} #{unit_label}"
    elsif min.present?
      "#{min}+ #{unit_label}"
    else
      "Up to #{max} #{unit_label}"
    end
  end

  def update_cached_stripe_shipping_rate!(stripe_shipping_rate_hash)
    return unless stripe_shipping_rate_hash.is_a?(Hash)

    cache_stripe_shipping_rate_data(stripe_shipping_rate_hash)
  end

  def clear_stripe_shipping_rate_cache!
    Rails.cache.delete(stripe_shipping_rate_cache_key) if stripe_shipping_rate_id.present?
    update_column(:stripe_shipping_rate_cache, {}) if persisted?
  end

  private

  def stripe_shipping_rate_cache_key
    "stripe_shipping_rate:#{stripe_shipping_rate_id}"
  end

  def fetch_and_cache_stripe_shipping_rate_data
    raw_rate = Stripe::ShippingRate.retrieve(stripe_shipping_rate_id)
    raw_rate = raw_rate.to_hash if raw_rate.respond_to?(:to_hash)
    raw_rate = raw_rate.to_h if raw_rate.respond_to?(:to_h)
    raw_rate = raw_rate.transform_keys(&:to_s) if raw_rate.respond_to?(:transform_keys)
    cache_stripe_shipping_rate_data(raw_rate)
    raw_rate
  end

  def cache_stripe_shipping_rate_data(raw_rate)
    Rails.cache.write(stripe_shipping_rate_cache_key, raw_rate, expires_in: STRIPE_SHIPPING_RATE_CACHE_EXPIRES_IN)

    return unless persisted?

    update_column(:stripe_shipping_rate_cache, raw_rate)
  end

  def clear_previous_stripe_shipping_rate_cache
    return unless stripe_shipping_rate_id_in_database.present?

    Rails.cache.delete("stripe_shipping_rate:#{stripe_shipping_rate_id_in_database}")
    self.stripe_shipping_rate_cache = {} if stripe_shipping_rate_cache.blank?
  end

  def broadcast_rate_removed
    Shipping::Broadcasts.rate_removed(self)
  end
end
