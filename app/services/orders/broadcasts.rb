module Orders
  module Broadcasts
    STREAM = "admin_orders".freeze
    TABLE_TARGET = "admin-orders".freeze

    def self.order_created(order)
      Turbo::StreamsChannel.broadcast_prepend_to(
        STREAM,
        target: TABLE_TARGET,
        partial: "admin/orders/order_row",
        locals: { order: order }
      )
    end

    def self.order_updated(order)
      Turbo::StreamsChannel.broadcast_replace_to(
        STREAM,
        target: row_dom_id(order),
        partial: "admin/orders/order_row",
        locals: { order: order }
      )

      Turbo::StreamsChannel.broadcast_replace_to(
        STREAM,
        target: detail_dom_id(order),
        partial: "admin/orders/detail",
        locals: { order: order }
      )
    end

    def self.order_removed(order)
      Turbo::StreamsChannel.broadcast_remove_to(
        STREAM,
        target: row_dom_id(order)
      )
    end

    def self.row_dom_id(order)
      ActionView::RecordIdentifier.dom_id(order, :admin_order)
    end

    def self.detail_dom_id(order)
      ActionView::RecordIdentifier.dom_id(order, :admin_order_detail)
    end
  end
end
