module Prodigi
  class CatalogDisplay
    Group = Struct.new(:sku, :label, :description, :frame_variants, :min_price_cents, :currency, keyword_init: true)
    FrameVariant = Struct.new(:frame, :label, :items, :min_price_cents, :currency, :shipping_summary, :delivery_window, :tracked_shipping, keyword_init: true)
    ColorOption = Struct.new(:color, :item, :price_cents, :currency, :available, keyword_init: true)

    def initialize(scope: ProdigiCatalogItem.all)
      @scope = scope.where.not(sku: nil).order(:sku, :frame, :color)
    end

    def sku_groups
      @sku_groups ||= @scope.to_a.group_by(&:sku).map do |sku, items|
        group_items(sku, items)
      end
    end

    private

    def group_items(sku, items)
      frame_variants = items.group_by { |item| item.frame.presence || "unframed" }
                            .map { |frame, frame_items| build_frame_variant(frame, frame_items) }
      first_item = items.first
      Group.new(
        sku: sku,
        label: sku,
        description: first_item.product_description,
        frame_variants: frame_variants,
        min_price_cents: items.map(&:product_price_amount_cents).compact.min,
        currency: first_item.product_currency
      )
    end

    def build_frame_variant(frame, items)
      color_options = items.group_by { |item| item.color.presence || "Standard" }
                           .map do |color, color_items|
        item = color_items.first
        ColorOption.new(
          color: color,
          item: item,
          price_cents: item.product_price_amount_cents,
          currency: item.product_currency,
          available: item.available_for_cart?
        )
      end

      first_item = items.first
      FrameVariant.new(
        frame: frame,
        label: first_item.frame_label,
        items: items,
        min_price_cents: items.map(&:product_price_amount_cents).compact.min,
        currency: first_item.product_currency,
        shipping_summary: first_item.shipping_summary,
        delivery_window: first_item.shipping_delivery_window_label,
        tracked_shipping: first_item.tracked_shipping_label
      )
    end
  end
end
