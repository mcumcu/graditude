module Admin
  class ShippingRateForm
    include ActiveModel::Model
    include ActiveModel::Attributes

    attr_accessor :shipping_rate

    attribute :display_name, :string
    attribute :product_format, :string
    attribute :billing_basis, :string
    attribute :amount, :string
    attribute :currency, :string, default: "usd"
    attribute :delivery_min_days, :integer
    attribute :delivery_max_days, :integer
    attribute :active, :boolean, default: true
    attribute :default_rate, :boolean, default: false

    validates :display_name, presence: true
    validates :product_format, presence: true, inclusion: { in: ShippingRate::FORMATS }
    validates :billing_basis, presence: true, inclusion: { in: ShippingRate::BILLING_BASIS }
    validate :validate_amount
    validate :validate_currency
    validate :validate_delivery_window
    validate :validate_default_state

    def self.from_shipping_rate(shipping_rate)
      stripe_rate = shipping_rate.stripe_shipping_rate_data || {}
      fixed_amount = stripe_rate.fetch("fixed_amount", {})
      estimate = stripe_rate.fetch("delivery_estimate", {})

      new(
        shipping_rate: shipping_rate,
        display_name: stripe_rate["display_name"],
        amount: format_amount(fixed_amount["amount"]),
        currency: fixed_amount["currency"] || "usd",
        delivery_min_days: estimate.dig("minimum", "value"),
        delivery_max_days: estimate.dig("maximum", "value"),
        product_format: shipping_rate.product_format,
        billing_basis: shipping_rate.billing_basis,
        active: shipping_rate.active,
        default_rate: shipping_rate.default_rate
      )
    end

    def save
      return false unless valid?

      provider = ::Shipping.provider

      if shipping_rate.present?
        update_shipping_rate(provider)
      else
        create_shipping_rate(provider)
      end
    end

    def archive
      return false unless shipping_rate.present?

      provider = ::Shipping.provider
      updated_rate = provider.deactivate_shipping_rate!(shipping_rate.stripe_shipping_rate_id)
      shipping_rate.update!(stripe_shipping_rate_cache: updated_rate, active: false, default_rate: false)
      true
    rescue Stripe::StripeError => error
      errors.add(:base, error.message)
      false
    end

    private

    def self.format_amount(amount_cents)
      return nil if amount_cents.blank?

      format("%.2f", amount_cents.to_f / 100.0)
    end

    private_class_method :format_amount

    def create_shipping_rate(provider)
      provider_rate = provider.create_shipping_rate!(
        display_name: display_name,
        amount_cents: amount_cents,
        currency: currency.to_s.downcase,
        delivery_min_days: delivery_min_days,
        delivery_max_days: delivery_max_days,
        active: active,
        metadata: metadata_payload
      )

      self.shipping_rate = ShippingRate.create!(
        stripe_shipping_rate_id: provider_rate.fetch("id"),
        stripe_shipping_rate_cache: provider_rate,
        product_format: product_format,
        billing_basis: billing_basis,
        active: active,
        default_rate: default_rate
      )

      enforce_single_default!
      true
    rescue Stripe::StripeError, ActiveRecord::RecordInvalid => error
      errors.add(:base, error.message)
      false
    end

    def update_shipping_rate(provider)
      if immutable_details_changed?
        provider_rate = provider.create_shipping_rate!(
          display_name: display_name,
          amount_cents: amount_cents,
          currency: currency.to_s.downcase,
          delivery_min_days: delivery_min_days,
          delivery_max_days: delivery_max_days,
          active: active,
          metadata: metadata_payload
        )

        provider.deactivate_shipping_rate!(shipping_rate.stripe_shipping_rate_id)
        shipping_rate.update!(
          stripe_shipping_rate_id: provider_rate.fetch("id"),
          stripe_shipping_rate_cache: provider_rate
        )
      else
        provider_rate = provider.update_shipping_rate!(
          shipping_rate.stripe_shipping_rate_id,
          active: active,
          metadata: metadata_payload
        )

        shipping_rate.update!(stripe_shipping_rate_cache: provider_rate)
      end

      shipping_rate.update!(
        product_format: product_format,
        billing_basis: billing_basis,
        active: active,
        default_rate: default_rate
      )

      enforce_single_default!
      true
    rescue Stripe::StripeError, ActiveRecord::RecordInvalid => error
      errors.add(:base, error.message)
      false
    end

    def enforce_single_default!
      return unless default_rate

      ShippingRate.where(product_format: product_format)
        .where.not(id: shipping_rate.id)
        .update_all(default_rate: false)
    end

    def amount_cents
      return nil if amount.blank?

      (BigDecimal(amount.to_s).round(2) * 100).to_i
    rescue ArgumentError
      nil
    end

    def amount_changed?
      return true unless shipping_rate

      current_amount = shipping_rate.stripe_amount_cents
      current_currency = shipping_rate.stripe_currency

      current_amount.to_i != amount_cents || current_currency.to_s.downcase != currency.to_s.downcase
    end

    def immutable_details_changed?
      amount_changed? || display_name_changed? || delivery_window_changed?
    end

    def display_name_changed?
      return true unless shipping_rate

      shipping_rate.stripe_display_name.to_s != display_name.to_s
    end

    def delivery_window_changed?
      return true unless shipping_rate

      estimate = shipping_rate.delivery_estimate || {}
      current_min = estimate.dig("minimum", "value")
      current_max = estimate.dig("maximum", "value")

      current_min.to_i != delivery_min_days.to_i || current_max.to_i != delivery_max_days.to_i
    end

    def metadata_payload
      {
        product_format: product_format,
        billing_basis: billing_basis
      }
    end

    def validate_amount
      cents = amount_cents

      if shipping_rate.nil? && cents.nil?
        errors.add(:amount, "is required")
        return
      end

      if amount.present? && cents.nil?
        errors.add(:amount, "must be a valid number")
      end

      if cents.to_i <= 0
        errors.add(:amount, "must be greater than zero")
      end
    end

    def validate_currency
      return if currency.to_s.strip.present?

      errors.add(:currency, "is required when setting a rate")
    end

    def validate_delivery_window
      if delivery_min_days.blank? && delivery_max_days.blank?
        errors.add(:delivery_min_days, "is required")
        errors.add(:delivery_max_days, "is required")
        return
      end

      if delivery_min_days.present? && delivery_min_days.to_i <= 0
        errors.add(:delivery_min_days, "must be greater than zero")
      end

      if delivery_max_days.present? && delivery_max_days.to_i <= 0
        errors.add(:delivery_max_days, "must be greater than zero")
      end

      if delivery_min_days.present? && delivery_max_days.present? && delivery_min_days.to_i > delivery_max_days.to_i
        errors.add(:delivery_max_days, "must be greater than or equal to the minimum")
      end
    end

    def validate_default_state
      return unless default_rate && !active

      errors.add(:default_rate, "requires the rate to be active")
    end
  end
end
