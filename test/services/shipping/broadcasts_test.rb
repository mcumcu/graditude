require "test_helper"

class Shipping::BroadcastsTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    ShippingRate.delete_all
  end

  test "rate_removed broadcasts Turbo remove with row dom id" do
    shipping_rate = ShippingRate.create!(
      stripe_shipping_rate_id: "shr_test_remove",
      stripe_shipping_rate_cache: {
        "id" => "shr_test_remove",
        "display_name" => "USPS Ground Advantage",
        "fixed_amount" => { "amount" => 1850, "currency" => "usd" }
      },
      product_format: "framed",
      billing_basis: "per_item",
      active: true,
      default_rate: false
    )

    captured = []
    with_stubbed_singleton_method(
      Turbo::StreamsChannel,
      :broadcast_remove_to,
      ->(stream, **opts) { captured << { stream: stream, opts: opts } }
    ) do
      Shipping::Broadcasts.rate_removed(shipping_rate)
    end

    assert_equal 1, captured.size
    assert_equal Shipping::Broadcasts::STREAM, captured.first[:stream]
    assert_equal Shipping::Broadcasts.row_dom_id(shipping_rate), captured.first[:opts][:target]
  end

  test "destroy invokes remove broadcast callback" do
    shipping_rate = ShippingRate.create!(
      stripe_shipping_rate_id: "shr_callback_remove",
      stripe_shipping_rate_cache: {
        "id" => "shr_callback_remove",
        "display_name" => "UPS Ground",
        "fixed_amount" => { "amount" => 1945, "currency" => "usd" }
      },
      product_format: "framed",
      billing_basis: "per_item",
      active: true,
      default_rate: false
    )

    captured = []
    with_stubbed_singleton_method(
      Shipping::Broadcasts,
      :rate_removed,
      ->(rate) { captured << rate }
    ) do
      shipping_rate.destroy!
    end

    assert_equal 1, captured.size
    assert_equal shipping_rate.id, captured.first.id
  end

  def with_stubbed_singleton_method(target, method_name, replacement)
    original = target.method(method_name)
    target.define_singleton_method(method_name, &replacement)
    yield
  ensure
    target.define_singleton_method(method_name, original.to_proc) if original
  end
end
