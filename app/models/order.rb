class Order < ApplicationRecord
  STATUS_FLOW = %w[order_placed processing shipping received].freeze
  TRANSITIONS = {
    "order_placed" => %w[processing canceled],
    "processing" => %w[order_placed shipping canceled],
    "shipping" => %w[processing received],
    "received" => [],
    "canceled" => []
  }.freeze

  belongs_to :user
  belongs_to :checkout_session

  after_create_commit :broadcast_order_created
  after_update_commit :broadcast_order_updated
  after_destroy_commit :broadcast_order_removed

  enum :status, {
    order_placed: "order_placed",
    processing: "processing",
    shipping: "shipping",
    received: "received",
    canceled: "canceled"
  }

  validates :checkout_session_id, uniqueness: true

  scope :recent_first, -> { order(created_at: :desc) }

  def raw_hash
    raw.presence || {}
  end

  def shipping_address_hash
    address = shipping_address.presence || {}
    return address.with_indifferent_access if address.respond_to?(:with_indifferent_access)

    address.to_h.with_indifferent_access
  end

  def number
    id.to_s.delete("-").first(8).upcase
  end

  def status_label
    status.humanize
  end

  def allowed_transition_statuses
    TRANSITIONS.fetch(status) { [] }
  end

  def can_transition_to?(target_status)
    allowed_transition_statuses.include?(target_status.to_s)
  end

  def transition_to!(target_status)
    target = target_status.to_s
    allowed_statuses = TRANSITIONS.fetch(status) { [] }
    raise ArgumentError, "Cannot transition order from #{status} to #{target}." unless allowed_statuses.include?(target)

    update!(status: target)
  end

  def checkout_items
    Array(checkout_session.items).map do |item|
      next item.with_indifferent_access if item.respond_to?(:with_indifferent_access)

      item.to_h.with_indifferent_access
    end
  end

  def subtotal_cents
    checkout_items.sum do |item|
      item[:unit_amount].to_i * item[:quantity].to_i
    end
  end

  def shipping_total_cents
    checkout_session.shipping_total_cents.to_i
  end

  def total_cents
    stripe_total_cents || subtotal_cents + shipping_total_cents
  end

  def currency
    checkout_items.find { |item| item[:currency].present? }&.[](:currency) ||
      checkout_session.shipping_currency.presence ||
      "usd"
  end

  def progress_index
    STATUS_FLOW.index(status) || 0
  end

  def previous_status_in_flow
    index = STATUS_FLOW.index(status)
    return nil unless index && index.positive?

    STATUS_FLOW[index - 1]
  end

  def return_transition_status
    previous_status = previous_status_in_flow
    return previous_status if previous_status && can_transition_to?(previous_status)

    nil
  end

  def shipping_address_lines
    details = shipping_address_hash
    address = details[:address] || {}
    locality = [ address[:city], address[:state] ].compact_blank.join(", ")
    locality = [ locality, address[:postal_code] ].compact_blank.join(" ")

    [
      details[:name],
      address[:line1],
      address[:line2],
      locality.presence,
      address[:country]
    ].compact_blank
  end

  def selected_shipping_options
    details = checkout_session.shipping_details_hash
    details = details.respond_to?(:with_indifferent_access) ? details.with_indifferent_access : details.to_h.with_indifferent_access

    Array(details[:rates]).filter_map do |rate|
      normalize_shipping_option(rate)
    end
  end

  def append_raw(payload)
    update!(raw: raw_hash.deep_merge(payload))
  end

  def process!
    transition_to!("processing")
  end

  def ship!
    transition_to!("shipping")
  end

  def receive!
    transition_to!("received")
  end

  def cancel!
    transition_to!("canceled")
  end

  private

  def broadcast_order_created
    Orders::Broadcasts.order_created(self)
  end

  def broadcast_order_updated
    Orders::Broadcasts.order_updated(self)
  end

  def broadcast_order_removed
    Orders::Broadcasts.order_removed(self)
  end

  def stripe_total_cents
    raw_hash.dig("stripe_session", "amount_total") || checkout_session.raw_hash.dig("stripe_session", "amount_total")
  end

  def normalize_shipping_option(rate)
    option = rate.respond_to?(:with_indifferent_access) ? rate.with_indifferent_access : rate.to_h.with_indifferent_access
    amount_cents = option[:total_cents].presence || option[:unit_amount_cents].presence
    summary = [
      shipping_option_format_label(option[:product_format]),
      shipping_option_quantity_label(option[:quantity], option[:billing_basis]),
      shipping_option_delivery_estimate_label(option[:delivery_estimate])
    ].compact.join(" • ").presence

    {
      display_name: option[:display_name].presence || "Shipping",
      summary: summary,
      amount_cents: amount_cents&.to_i,
      currency: option[:currency].presence || currency
    }.compact
  end

  def shipping_option_format_label(format)
    case format.to_s
    when "framed"
      "Framed"
    when "unframed"
      "Print"
    else
      format.to_s.humanize.presence
    end
  end

  def shipping_option_quantity_label(quantity, billing_basis)
    quantity = quantity.to_i

    if billing_basis.to_s == "per_item" && quantity.positive?
      ActionController::Base.helpers.pluralize(quantity, "item")
    elsif billing_basis.to_s == "per_order"
      "Per order"
    end
  end

  def shipping_option_delivery_estimate_label(estimate)
    return nil if estimate.blank?

    estimate = estimate.to_hash if estimate.respond_to?(:to_hash)
    estimate = estimate.to_h if estimate.respond_to?(:to_h)
    estimate = estimate.with_indifferent_access if estimate.respond_to?(:with_indifferent_access)

    minimum = estimate.dig(:minimum, :value)
    maximum = estimate.dig(:maximum, :value)
    unit = estimate.dig(:minimum, :unit) || estimate.dig(:maximum, :unit)
    return nil if minimum.blank? && maximum.blank?

    unit_label = unit.to_s == "business_day" ? "Business Days" : unit.to_s.tr("_", " ").titleize
    if minimum.present? && maximum.present?
      "#{minimum}-#{maximum} #{unit_label}"
    elsif minimum.present?
      "#{minimum}+ #{unit_label}"
    else
      "Up to #{maximum} #{unit_label}"
    end
  end
end
