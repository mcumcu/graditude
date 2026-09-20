require "test_helper"
require "admin/catalog_product_form"

class Admin::CatalogProductFormTest < ActionDispatch::IntegrationTest
  setup do
    @product = Product.create!(
      name: "Test Product",
      sku: "SKU-001",
      price: 1000,
      currency: "USD",
      extra_metadata: { key: "value" },
      extra_product: { attribute: "data" }
    )
  end

  teardown do
    @product&.destroy
  end

  test "from_product should create form from existing model" do
    form = Admin::CatalogProductForm.from_product(@product)
    assert_equal @product.name, form.name
    assert_equal @product.sku, form.sku
    assert_equal @product.price, form.price
    assert_equal @product.currency, form.currency
    assert_equal @product.extra_metadata, form.extra_metadata
    assert_equal @product.extra_product, form.extra_product
  end

  test "from_product should handle nil extra_metadata" do
    product = Product.create!(name: "Test Product", sku: "SKU-001", price: 1000, currency: "USD")
    form = Admin::CatalogProductForm.from_product(product)
    assert_nil form.extra_metadata
    product.destroy
  end

  test "from_product should handle nil extra_product" do
    product = Product.create!(name: "Test Product", sku: "SKU-001", price: 1000, currency: "USD")
    form = Admin::CatalogProductForm.from_product(product)
    assert_nil form.extra_product
    product.destroy
  end

  test "save should create Stripe product and price" do
    form = Admin::CatalogProductForm.new(
      name: "Test Product",
      sku: "SKU-001",
      price: 1000,
      currency: "USD"
    )
    assert form.valid?
    form.save
    assert form.persisted?
    assert form.stripe_product.present?
    assert form.stripe_price.present?
  end

  test "save should update existing Stripe product and price" do
    form = Admin::CatalogProductForm.from_product(@product)
    form.name = "Updated Product"
    form.price = 2000
    assert form.valid?
    form.save
    assert form.persisted?
    assert_equal "Updated Product", form.stripe_product.name
    assert_equal 2000, form.stripe_price.unit_amount
  end

  test "save should handle invalid Stripe product creation" do
    form = Admin::CatalogProductForm.new(
      name: "Test Product",
      sku: "SKU-001",
      price: 1000,
      currency: "USD"
    )
    form.stripe_product = nil
    form.save
    assert_not form.persisted?
    assert_includes form.errors[:stripe_product], "can't be blank"
  end

  test "archive should archive product" do
    form = Admin::CatalogProductForm.from_product(@product)
    form.state = "archived"
    form.save
    assert form.persisted?
    assert_equal "archived", form.stripe_product.metadata["state"]
  end

  test "validate_price should require price" do
    form = Admin::CatalogProductForm.new(
      name: "Test Product",
      price: nil,
      currency: "USD"
    )
    assert_not form.valid?
    assert_includes form.errors[:price], "can't be blank"
  end

  test "validate_price should require valid amount" do
    form = Admin::CatalogProductForm.new(
      name: "Test Product",
      price: "not_a_number",
      currency: "USD"
    )
    assert_not form.valid?
    assert_includes form.errors[:price], "is not a number"
  end

  test "validate_price should require valid currency" do
    form = Admin::CatalogProductForm.new(
      name: "Test Product",
      price: 1000,
      currency: "INVALID"
    )
    assert_not form.valid?
    assert_includes form.errors[:currency], "is not included in the list"
  end

  test "validate_json_fields should require valid JSON" do
    form = Admin::CatalogProductForm.new(
      name: "Test Product",
      price: 1000,
      currency: "USD",
      json_fields: "invalid json"
    )
    assert_not form.valid?
    assert_includes form.errors[:json_fields], "is not a valid JSON"
  end

  test "validate_json_fields should reject invalid keys" do
    form = Admin::CatalogProductForm.new(
      name: "Test Product",
      price: 1000,
      currency: "USD",
      json_fields: '{"invalid_key": "value"}'
    )
    assert_not form.valid?
    assert_includes form.errors[:json_fields], "contains invalid keys"
  end

  test "price_amount_cents should return price in cents" do
    form = Admin::CatalogProductForm.new(
      name: "Test Product",
      price: 1000,
      currency: "USD"
    )
    assert_equal 1000, form.price_amount_cents
  end

  test "price_amount_cents should handle nil price" do
    form = Admin::CatalogProductForm.new(
      name: "Test Product",
      price: nil,
      currency: "USD"
    )
    assert_nil form.price_amount_cents
  end

  test "parsed_extra_metadata should parse JSON metadata" do
    form = Admin::CatalogProductForm.new(
      name: "Test Product",
      price: 1000,
      currency: "USD",
      extra_metadata: { key: "value", nested: { inner: "data" } }
    )
    assert_equal({ key: "value", nested: { inner: "data" } }, form.parsed_extra_metadata)
  end

  test "parsed_extra_product should parse JSON product" do
    form = Admin::CatalogProductForm.new(
      name: "Test Product",
      price: 1000,
      currency: "USD",
      extra_product: { attribute: "data", nested: { inner: "value" } }
    )
    assert_equal({ attribute: "data", nested: { inner: "value" } }, form.parsed_extra_product)
  end
end
