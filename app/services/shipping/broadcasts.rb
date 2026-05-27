module Shipping
  module Broadcasts
    STREAM = "admin_shipping_rates".freeze
    TABLE_TARGET = "admin-shipping-rates".freeze

    def self.rate_created(shipping_rate)
      Turbo::StreamsChannel.broadcast_prepend_to(
        STREAM,
        target: TABLE_TARGET,
        partial: "admin/shipping_rates/rate_row",
        locals: { shipping_rate: shipping_rate }
      )
    end

    def self.rate_updated(shipping_rate)
      Turbo::StreamsChannel.broadcast_replace_to(
        STREAM,
        target: row_dom_id(shipping_rate),
        partial: "admin/shipping_rates/rate_row",
        locals: { shipping_rate: shipping_rate }
      )
    end

    def self.rate_removed(shipping_rate)
      Turbo::StreamsChannel.broadcast_remove_to(
        STREAM,
        target: row_dom_id(shipping_rate)
      )
    end

    def self.row_dom_id(shipping_rate)
      ActionView::RecordIdentifier.dom_id(shipping_rate, :admin_shipping_rate)
    end
  end
end
