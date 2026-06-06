class ProdigiCatalogItem < ApplicationRecord
  has_one :prodigi_stripe_mapping, dependent: :destroy

  validates :row_key, presence: true, uniqueness: true
  validates :sku, presence: true
  validates :destination_country, presence: true
  validates :variant_fingerprint, presence: true

  scope :for_sku, ->(sku) { where(sku: sku.to_s.strip.upcase) }
  scope :for_destination, ->(country_code) { where(destination_country: country_code.to_s.strip.upcase) }
  scope :for_product_family, ->(family) { where(product_family: family) }
  scope :with_shipping_method, ->(shipping_method) { where(shipping_method: shipping_method.to_s.strip.presence) }

  def product_family
    self[:product_family].presence || self.class.resolve_product_family(raw_row_data)
  end

  def variant_key
    @variant_key ||= [ product_family, size_label, color, frame, paper_type ].compact.map(&:to_s).join("|")
  end

  def size_label
    return size_inches if size_inches.present?
    return "#{size_cm}cm" if size_cm.present?

    nil
  end

  def shipping_total_cents(quantity = 1)
    return nil if shipping_price_cents.blank?

    count = quantity.to_i
    count = 1 if count < 1
    base = shipping_price_cents.to_i
    additional = plus_one_shipping_price_cents.to_i
    base + additional * [ count - 1, 0 ].max
  end

  def shipping_delivery_window_label
    return nil if minimum_shipping_days.blank? && maximum_shipping_days.blank?

    if minimum_shipping_days.present? && maximum_shipping_days.present?
      "#{minimum_shipping_days}-#{maximum_shipping_days} Business Days"
    elsif minimum_shipping_days.present?
      "#{minimum_shipping_days}+ Business Days"
    else
      "Up to #{maximum_shipping_days} Business Days"
    end
  end

  def formatted_variant_name
    components = []
    components << size_label if size_label.present?
    components << color if color.present?
    components << frame if frame.present?
    components << paper_type if paper_type.present?
    components.join(" - ")
  end

  def frame_label
    frame.presence || "Unframed"
  end

  def color_label
    color.presence || "Standard"
  end

  def product_description
    prodigi_product_details["product_description"].presence || raw_row_data["product_description"].presence || "Premium printed gratitude certificates fulfilled through Prodigi."
  end

  def shipping_summary
    return nil unless shipping_price_cents.present? && shipping_currency.present?

    {
      price_cents: shipping_price_cents,
      currency: shipping_currency,
      delivery_window: shipping_delivery_window_label.presence,
      tracked_shipping: tracked_shipping_label.presence
    }
  end

  def tracked_shipping_label
    return nil if tracked_shipping.nil?

    tracked_shipping ? "Tracked shipping included" : "Untracked shipping"
  end

  def available_for_cart?
    stripe_price_id.present? && associated_product.present? && associated_product.active?
  end

  def stripe_price_id
    prodigi_stripe_mapping&.stripe_price_id
  end

  def associated_product
    return unless prodigi_stripe_mapping&.stripe_product_id.present?

    Product.find_by(stripe_product_id: prodigi_stripe_mapping.stripe_product_id)
  end

  def self.resolve_product_family(raw_data)
    category = raw_data.to_h.fetch("category", nil).to_s.downcase
    product_type = raw_data.to_h.fetch("product_type", nil).to_s.downcase

    return "framed" if category.include?("wall art") || product_type.include?("framed")
    return "printed" if category.include?("print") || product_type.include?("print")

    "printed"
  end
end
