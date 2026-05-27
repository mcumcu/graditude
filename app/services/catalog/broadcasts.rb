module Catalog
  module Broadcasts
    STREAM = "admin_catalog".freeze
    TABLE_TARGET = "admin-catalog-products".freeze

    def self.product_created(product)
      Turbo::StreamsChannel.broadcast_prepend_to(
        STREAM,
        target: TABLE_TARGET,
        partial: "admin/catalog/products/product_row",
        locals: { product: product }
      )
    end

    def self.product_updated(product)
      Turbo::StreamsChannel.broadcast_replace_to(
        STREAM,
        target: row_dom_id(product),
        partial: "admin/catalog/products/product_row",
        locals: { product: product }
      )
    end

    def self.product_removed(product)
      Turbo::StreamsChannel.broadcast_remove_to(
        STREAM,
        target: row_dom_id(product)
      )
    end

    def self.row_dom_id(product)
      ActionView::RecordIdentifier.dom_id(product, :admin_catalog)
    end
  end
end
