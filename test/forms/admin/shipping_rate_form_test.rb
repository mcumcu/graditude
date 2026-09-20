require "test_helper"
require "admin/shipping_rate_form"

class Admin::ShippingRateFormTest < ActionDispatch::IntegrationTest
  setup do
    @product = Product.create!(name: "Test Product", sku: "SKU-001")
    @shipping_rate = ShippingRate.create!(
      product: @product,
      display_name: "Test Rate",
      product_format: ShippingRate::FORMATS[:framed],
      billing_basis: ShippingRate::BILLING_BASIS[:per_item],
      amount: 1000,
      currency: "USD",
      delivery_window_start: 1,
      delivery_window_end: 7
    )
  end

  teardown do
    @shipping_rate&.destroy
    @product&.destroy
  end

  test "should be valid with all required attributes" do
    form = Admin::ShippingRateForm.new(
      display_name: "Test Rate",
      product_format: "framed",
      billing_basis: "per_item",
      amount: 1000,
      currency: "USD",
      delivery_window_start: 1,
      delivery_window_end: 7
    )
    assert form.valid?
  end

  test "should be invalid with missing display_name" do
    form = Admin::ShippingRateForm.new(
      product_format: "framed",
      billing_basis: "per_item",
      amount: 1000,
      currency: "USD"
    )
    assert_not form.valid?
    assert_includes form.errors[:display_name], "can't be blank"
  end

  test "should be invalid with invalid product_format" do
    form = Admin::ShippingRateForm.new(
      display_name: "Test Rate",
      product_format: "invalid_format",
      billing_basis: "per_item",
      amount: 1000,
      currency: "USD"
    )
    assert_not form.valid?
    assert_includes form.errors[:product_format], "is not included in the list"
  end

  test "should be invalid with invalid billing_basis" do
    form = Admin::ShippingRateForm.new(
      display_name: "Test Rate",
      product_format: "framed",
      billing_basis: "invalid_basis",
      amount: 1000,
      currency: "USD"
    )
    assert_not form.valid?
    assert_includes form.errors[:billing_basis], "is not included in the list"
  end

  test "should be invalid with invalid amount" do
    form = Admin::ShippingRateForm.new(
      display_name: "Test Rate",
      product_format: "framed",
      billing_basis: "per_item",
      amount: "not_a_number",
      currency: "USD"
    )
    assert_not form.valid?
    assert_includes form.errors[:amount], "is not a number"
  end

  test "should be invalid with invalid currency" do
    form = Admin::ShippingRateForm.new(
      display_name: "Test Rate",
      product_format: "framed",
      billing_basis: "per_item",
      amount: 1000,
      currency: "INVALID"
    )
    assert_not form.valid?
    assert_includes form.errors[:currency], "is not included in the list"
  end

  test "should be invalid with invalid delivery window" do
    form = Admin::ShippingRateForm.new(
      display_name: "Test Rate",
      product_format: "framed",
      billing_basis: "per_item",
      amount: 1000,
      currency: "USD",
      delivery_window_start: 10,
      delivery_window_end: 5
    )
    assert_not form.valid?
    assert_includes form.errors[:delivery_window_start], "must be less than or equal to delivery_window_end"
  end

  test "should be invalid with delivery window outside range" do
    form = Admin::ShippingRateForm.new(
      display_name: "Test Rate",
      product_format: "framed",
      billing_basis: "per_item",
      amount: 1000,
      currency: "USD",
      delivery_window_start: 0,
      delivery_window_end: 30
    )
    assert_not form.valid?
    assert_includes form.errors[:delivery_window_start], "must be between 1 and 30"
  end

  test "should be invalid when default is true but state is not active" do
    form = Admin::ShippingRateForm.new(
      display_name: "Test Rate",
      product_format: "framed",
      billing_basis: "per_item",
      amount: 1000,
      currency: "USD",
      delivery_window_start: 1,
      delivery_window_end: 7,
      default: true,
      state: "inactive"
    )
    assert_not form.valid?
    assert_includes form.errors[:default], "must be false when state is not active"
  end

  test "from_shipping_rate should create form from existing model" do
    form = Admin::ShippingRateForm.from_shipping_rate(@shipping_rate)
    assert_equal @shipping_rate.display_name, form.display_name
    assert_equal @shipping_rate.product_format, form.product_format
    assert_equal @shipping_rate.billing_basis, form.billing_basis
    assert_equal @shipping_rate.amount, form.amount
    assert_equal @shipping_rate.currency, form.currency
    assert_equal @shipping_rate.delivery_window_start, form.delivery_window_start
    assert_equal @shipping_rate.delivery_window_end, form.delivery_window_end
    assert_equal @shipping_rate.default, form.default
    assert_equal @shipping_rate.state, form.state
  end

  test "save should create Stripe shipping rate" do
    form = Admin::ShippingRateForm.new(
      display_name: "Test Rate",
      product_format: "framed",
      billing_basis: "per_item",
      amount: 1000,
      currency: "USD",
      delivery_window_start: 1,
      delivery_window_end: 7
    )
    assert form.valid?
    form.save
    assert form.persisted?
    assert form.shipping_rate.present?
  end

  test "save should update existing Stripe shipping rate" do
    form = Admin::ShippingRateForm.from_shipping_rate(@shipping_rate)
    form.display_name = "Updated Rate"
    form.amount = 2000
    assert form.valid?
    form.save
    assert form.persisted?
    assert_equal "Updated Rate", form.shipping_rate.display_name
    assert_equal 2000, form.shipping_rate.amount
  end

  test "archive should deactivate shipping rate" do
    form = Admin::ShippingRateForm.from_shipping_rate(@shipping_rate)
    form.state = "inactive"
    assert form.valid?
    form.save
    form.archive
    assert_equal "inactive", form.shipping_rate.state
  end

  test "amount_cents should return amount in cents" do
    form = Admin::ShippingRateForm.new(
      display_name: "Test Rate",
      product_format: "framed",
      billing_basis: "per_item",
      amount: 1000,
      currency: "USD"
    )
    assert_equal 1000, form.amount_cents
  end

  test "amount_cents should handle nil amount" do
    form = Admin::ShippingRateForm.new(
      display_name: "Test Rate",
      product_format: "framed",
      billing_basis: "per_item",
      amount: nil,
      currency: "USD"
    )
    assert_nil form.amount_cents
  end

  test "immutable_details_changed? should return false when only default changes" do
    form = Admin::ShippingRateForm.new(
      display_name: "Test Rate",
      product_format: "framed",
      billing_basis: "per_item",
      amount: 1000,
      currency: "USD",
      delivery_window_start: 1,
      delivery_window_end: 7,
      default: true
    )
    form.default = false
    assert_not form.immutable_details_changed?
  end

  test "immutable_details_changed? should return true when display_name changes" do
    form = Admin::ShippingRateForm.new(
      display_name: "Test Rate",
      product_format: "framed",
      billing_basis: "per_item",
      amount: 1000,
      currency: "USD",
      delivery_window_start: 1,
      delivery_window_end: 7
    )
    form.display_name = "New Rate"
    assert form.immutable_details_changed?
  end

  test "amount_changed? should return true when amount changes" do
    form = Admin::ShippingRateForm.new(
      display_name: "Test Rate",
      product_format: "framed",
      billing_basis: "per_item",
      amount: 1000,
      currency: "USD",
      delivery_window_start: 1,
      delivery_window_end: 7
    )
    form.amount = 2000
    assert form.amount_changed?
  end
end