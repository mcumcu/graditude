class Product < ApplicationRecord
  has_many :certificate_products, dependent: :restrict_with_error
  has_many :prices, dependent: :destroy

  validates :stripe_product_id, uniqueness: true, allow_blank: true

  STRIPE_PRODUCT_CACHE_EXPIRES_IN = 1.hour
  DEFAULT_HEADING = "Graditude Certificate"
  DEFAULT_EYEBROW = "Gift from the graduate"
  DEFAULT_DESCRIPTION_PARAGRAPHS = [
    "A gratitude certificate from the graduate to the parents, mentors, coaches, and benefactors who helped them reach this moment.",
    "Personalize the names, degree, and message, then choose a framed or unframed finish that fits your gifting moment."
  ].freeze
  DEFAULT_DETAIL_INTRO = "Thoughtful typography, balanced layout, and a premium print finish make each certificate worthy of the people who supported the graduate."
  DEFAULT_DETAIL_ITEMS = [
    "Customize the graduate name, honoree, degree, and message to capture the exact gratitude that should be preserved.",
    "Choose framed for a ready-to-display presentation or unframed for flexible gifting and future framing."
  ].freeze
  DEFAULT_MARKETING_FEATURES = [
    {
      "name" => "Premium print",
      "description" => "Archival-quality printing with crisp typography and clean layout."
    },
    {
      "name" => "Reliable delivery",
      "description" => "Trackable shipping with delivery updates to your inbox."
    },
    {
      "name" => "Support you can reach",
      "description" => "Email support@thegraditude.com for any order questions."
    },
    {
      "name" => "Thoughtful gifting",
      "description" => "Designed to honor the people who supported the graduate."
    }
  ].freeze
  DEFAULT_SHORT_DESCRIPTION = "Museum-grade print and ready-to-gift presentation."

  before_save :clear_previous_stripe_product_cache, if: :will_save_change_to_stripe_product_id?
  after_destroy :clear_stripe_product_cache!

  def stripe_product_cache
    self[:stripe_product_cache]
  end

  def stripe_product_data(reload: false)
    return unless stripe_product_id.present?

    data = if reload
      clear_stripe_product_cache!
      fetch_and_cache_stripe_product_data
    else
      Rails.cache.fetch(stripe_product_cache_key, expires_in: STRIPE_PRODUCT_CACHE_EXPIRES_IN, skip_nil: true) do
        stripe_product_cache.presence || fetch_and_cache_stripe_product_data
      end
    end

    Catalog::Normalizer.hashify(data)
  end

  def stripe_product(reload: false)
    stripe_product_data(reload: reload)
  end

  def catalog_data(reload: false, with_defaults: true, infer_variant_format: true, include_price: true)
    @catalog_data ||= {}
    cache_key = [ with_defaults, infer_variant_format, include_price ]
    if reload || @catalog_data[cache_key].nil?
      price_data = include_price ? default_price&.stripe_price_data(reload: reload) : nil
      if include_price && !reload
        price_hash = Catalog::Normalizer.hashify(price_data)
        if price_hash["unit_amount"].blank? && price_hash["unit_amount_decimal"].blank?
          price_data = default_price&.stripe_price_data(reload: true)
        end
      end
      @catalog_data[cache_key] = Catalog::Contract.from_stripe(
        product: stripe_product_data(reload: reload),
        price: price_data,
        with_defaults: with_defaults,
        infer_variant_format: infer_variant_format
      )
    end

    @catalog_data[cache_key]
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

  def display_name
    catalog_data(include_price: false)[:heading]
  end

  def display_eyebrow
    catalog_data(include_price: false)[:eyebrow]
  end

  def display_description_paragraphs
    catalog_data(include_price: false)[:description_paragraphs]
  end

  def display_description
    catalog_data(include_price: false)[:description]
  end

  def display_short_description
    catalog_data(include_price: false)[:short_description]
  end

  def display_detail_intro
    catalog_data(include_price: false)[:detail_intro]
  end

  def display_attributes
    catalog_data(include_price: false)[:attributes]
  end

  def display_marketing_features
    catalog_data(include_price: false)[:marketing_features]
  end

  def stripe_metadata
    stripe_product_data&.fetch("metadata", {}) || {}
  end

  def certificate_template_names
    catalog_data(with_defaults: false, include_price: false)[:certificate_templates]
  end

  def variant_format
    catalog_data(include_price: false)[:variant_format]
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

    normalized = Catalog::Normalizer.hashify(stripe_product_hash)
    return if normalized.blank?

    cache_stripe_product_data(normalized)
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
    normalized = Catalog::Normalizer.hashify(raw_product)
    cache_stripe_product_data(normalized)
    normalized
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
