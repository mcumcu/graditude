require "test_helper"

class Prodigi::CatalogCsvImporterTest < ActiveSupport::TestCase
  test "normalizes actual products-prices.csv headers and parses sample row values" do
    importer = Prodigi::CatalogCsvImporter.new(path: Rails.root.join("lib/tasks/products-prices.csv"))
    first_row = CSV.foreach(Rails.root.join("lib/tasks/products-prices.csv"), headers: true).first

    assert_not_nil first_row, "Expected at least one row in products-prices.csv"

    attrs = importer.send(:build_attributes, first_row.to_h)

    assert_equal "GLOBAL-FAP-8_5X11", attrs[:sku]
    assert_equal "US", attrs[:destination_country]
    assert_equal "Standard Plus", attrs[:shipping_method]
    assert_equal 1100, attrs[:product_price_amount_cents]
    assert_equal "USD", attrs[:product_currency]
    assert_equal true, attrs[:tracked_shipping]
    assert_equal "8.5x11\"", attrs[:size_inches]
    assert_equal "EMA", attrs[:paper_type]
    assert_equal "product_type", importer.send(:canonical_header_name, "product_type")
    assert_equal "shipping_method", importer.send(:canonical_header_name, "shipping_method")

    expected_row_count = CSV.read(Rails.root.join("lib/tasks/products-prices.csv"), headers: true).size

    initial_run_count = ProdigiPipelineRun.count
    importer.call!
    assert_equal initial_run_count + 1, ProdigiPipelineRun.count
    run = ProdigiPipelineRun.order(created_at: :desc).first
    assert_equal "import_catalog", run.phase
    assert_equal "completed", run.status
    assert_equal expected_row_count, run.record_count
    assert_equal expected_row_count, run.created_count
  end
end
