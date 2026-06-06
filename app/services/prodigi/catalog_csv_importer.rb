require "csv"
require "digest"

module Prodigi
  class CatalogCsvImporter
    DEFAULT_PATH = Rails.root.join("lib", "tasks", "products-prices.csv").freeze

    HEADER_MAPPINGS = {
      "sku" => "sku",
      "category" => "category",
      "product type" => "product_type",
      "product_type" => "product_type",
      "product description" => "product_description",
      "color" => "color",
      "frame" => "frame",
      "paper type" => "paper_type",
      "paper_type" => "paper_type",
      "size (cm)" => "size_cm",
      "size_cm" => "size_cm",
      "size (inches)" => "size_inches",
      "size_inches" => "size_inches",
      "substrate weight" => "substrate_weight",
      "product price" => "product_price",
      "product_currency" => "product_currency",
      "product currency" => "product_currency",
      "source country" => "source_country",
      "destination country" => "destination_country",
      "shipping method" => "shipping_method",
      "shipping price" => "shipping_price",
      "plus one shipping price" => "plus_one_shipping_price",
      "shipping currency" => "shipping_currency",
      "minimum shipping (days)" => "minimum_shipping_days",
      "minimum_shipping_days" => "minimum_shipping_days",
      "maximum shipping (days)" => "maximum_shipping_days",
      "maximum_shipping_days" => "maximum_shipping_days",
      "tracked shipping" => "tracked_shipping",
      "tracked_shipping" => "tracked_shipping"
    }.freeze

    def initialize(path: DEFAULT_PATH, dry_run: false)
      @path = Pathname(path)
      @dry_run = dry_run
    end

    def call!
      result = {
        path: @path.to_s,
        processed: 0,
        created: 0,
        updated: 0,
        skipped: 0
      }

      if @dry_run
        ActiveRecord::Base.transaction do
          process_rows(result)
          raise ActiveRecord::Rollback
        end
      else
        Prodigi::PipelineRunTracker.track(phase: "import_catalog") do
          process_rows(result)
          result
        end
      end

      result
    end

    def process_rows(result)
      CSV.foreach(@path, headers: true) do |row|
        attrs = build_attributes(row.to_h)
        if attrs[:sku].blank? || attrs[:destination_country].blank?
          result[:skipped] += 1
          next
        end

        result[:processed] += 1
        record = ProdigiCatalogItem.find_or_initialize_by(row_key: attrs[:row_key])
        was_new_record = record.new_record?
        record.assign_attributes(attrs)
        if record.save
          result[was_new_record ? :created : :updated] += 1
        else
          result[:skipped] += 1
        end
      end
    end

    private

    def build_attributes(raw_row)
      normalized = normalize_row(raw_row)
      sku = normalized.fetch("sku", nil)
      destination_country = normalized.fetch("destination_country", nil)
      product_family = ProdigiCatalogItem.resolve_product_family(normalized)
      variant_fingerprint = build_variant_fingerprint(normalized)
      row_key = Digest::SHA256.hexdigest(
        [
          sku,
          destination_country,
          normalized.fetch("shipping_method", nil),
          product_family,
          variant_fingerprint,
          normalized.fetch("product_currency", nil)
        ].map { |value| value.to_s.strip.upcase }.join("|")
      )

      {
        row_key: row_key,
        sku: sku,
        destination_country: destination_country,
        product_family: product_family,
        shipping_method: normalized.fetch("shipping_method", nil),
        size_cm: normalized.fetch("size_cm", nil),
        size_inches: normalized.fetch("size_inches", nil),
        color: normalized.fetch("color", nil),
        frame: normalized.fetch("frame", nil),
        paper_type: normalized.fetch("paper_type", nil),
        product_price_amount_cents: money_to_cents(normalized.fetch("product_price", nil)),
        product_currency: normalized.fetch("product_currency", nil),
        shipping_price_cents: money_to_cents(normalized.fetch("shipping_price", nil)),
        plus_one_shipping_price_cents: money_to_cents(normalized.fetch("plus_one_shipping_price", nil)),
        shipping_currency: normalized.fetch("shipping_currency", nil),
        minimum_shipping_days: integer_or_nil(normalized.fetch("minimum_shipping_days", nil)),
        maximum_shipping_days: integer_or_nil(normalized.fetch("maximum_shipping_days", nil)),
        tracked_shipping: tracked_shipping_value(normalized.fetch("tracked_shipping", nil)),
        variant_fingerprint: variant_fingerprint,
        raw_row_data: normalized.compact_blank,
        prodigi_product_details: build_product_details(normalized, product_family)
      }
    end

    def normalize_row(raw_row)
      raw_row.to_h.each_with_object({}) do |(key, value), memo|
        normalized_key = canonical_header_name(key)
        memo[normalized_key] = value.to_s.strip.presence
      end
    end

    def canonical_header_name(header)
      return header if header.blank?

      header_text = header.to_s.strip.delete_prefix("\uFEFF").downcase
      normalized = header_text.gsub(/[^a-z0-9]+/, "_").gsub(/\A_|_\z/, "")
      HEADER_MAPPINGS.fetch(normalized, normalized)
    end

    def build_variant_fingerprint(normalized)
      values = [
        normalized.fetch("sku", nil),
        normalized.fetch("size_cm", nil),
        normalized.fetch("size_inches", nil),
        normalized.fetch("color", nil),
        normalized.fetch("frame", nil),
        normalized.fetch("paper_type", nil)
      ]
      Digest::SHA256.hexdigest(values.map { |value| value.to_s.strip.upcase }.join("|"))
    end

    def build_product_details(normalized, product_family)
      {
        category: normalized.fetch("category", nil),
        product_type: normalized.fetch("product_type", nil),
        product_description: normalized.fetch("product_description", nil),
        product_family: product_family,
        size_cm: normalized.fetch("size_cm", nil),
        size_inches: normalized.fetch("size_inches", nil),
        substrate_weight: normalized.fetch("substrate_weight", nil),
        color: normalized.fetch("color", nil),
        frame: normalized.fetch("frame", nil),
        paper_type: normalized.fetch("paper_type", nil),
        product_price: normalized.fetch("product_price", nil),
        product_currency: normalized.fetch("product_currency", nil),
        shipping_method: normalized.fetch("shipping_method", nil),
        shipping_price: normalized.fetch("shipping_price", nil),
        plus_one_shipping_price: normalized.fetch("plus_one_shipping_price", nil),
        shipping_currency: normalized.fetch("shipping_currency", nil),
        minimum_shipping_days: normalized.fetch("minimum_shipping_days", nil),
        maximum_shipping_days: normalized.fetch("maximum_shipping_days", nil),
        tracked_shipping: normalized.fetch("tracked_shipping", nil)
      }.compact_blank
    end

    def money_to_cents(value)
      return nil if value.blank?
      (BigDecimal(value.to_s) * 100).round(0).to_i
    rescue ArgumentError
      nil
    end

    def integer_or_nil(value)
      return nil if value.blank?
      Integer(value)
    rescue ArgumentError
      nil
    end

    def tracked_shipping_value(value)
      return nil if value.blank?
      normalized = value.to_s.strip.downcase
      return true if %w[tracked yes true].include?(normalized)
      return false if %w[untracked no false].include?(normalized)
      nil
    end
  end
end
