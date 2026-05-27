class BackfillOrderShippingAddresses < ActiveRecord::Migration[8.1]
  class MigrationOrder < ApplicationRecord
    self.table_name = "orders"

    belongs_to :checkout_session, class_name: "BackfillOrderShippingAddresses::MigrationCheckoutSession"
  end

  class MigrationCheckoutSession < ApplicationRecord
    self.table_name = "checkout_sessions"
  end

  def up
    say_with_time "Backfilling canonical order shipping addresses" do
      MigrationOrder.includes(:checkout_session).find_each do |order|
        shipping_address = extract_shipping_address(order.checkout_session)
        next if shipping_address.blank?

        order.update_columns(shipping_address: shipping_address)
      end
    end
  end

  def down
    # Keep populated canonical shipping addresses in place.
  end

  private

  def extract_shipping_address(checkout_session)
    return {} unless checkout_session

    shipping_details = normalize_hash(checkout_session.shipping_details)["stripe_shipping_details"]
    normalized_shipping = normalize_address_details(shipping_details)
    return normalized_shipping.merge("source" => "stripe_shipping_details") if normalized_shipping.present?

    customer_details = normalize_hash(checkout_session.raw)["stripe_session"]
    customer_details = normalize_hash(customer_details)["customer_details"]
    normalized_customer = normalize_address_details(customer_details)
    return normalized_customer.merge("source" => "stripe_customer_details") if normalized_customer.present?

    {}
  end

  def normalize_address_details(details)
    details = normalize_hash(details)
    return {} if details.blank?

    address = normalize_hash(details["address"])
    payload = {
      "name" => details["name"],
      "phone" => details["phone"],
      "address" => address.presence
    }.compact

    payload.except("address") if payload["address"].blank?
    payload.compact_blank
  end

  def normalize_hash(value)
    return {} if value.blank?

    value = value.to_hash if value.respond_to?(:to_hash)
    value = value.to_h if value.respond_to?(:to_h)
    value = value.transform_keys(&:to_s) if value.respond_to?(:transform_keys)
    value.is_a?(Hash) ? value : {}
  end
end
