require "test_helper"

class Admin::ShippingRatesControllerTest < ActionDispatch::IntegrationTest
  class FakeProvider
    def create_shipping_rate!(display_name:, amount_cents:, currency:, delivery_min_days:, delivery_max_days:, active:, metadata: {})
      {
        "id" => "shr_fake",
        "display_name" => display_name,
        "fixed_amount" => { "amount" => amount_cents, "currency" => currency },
        "delivery_estimate" => {
          "minimum" => { "unit" => "business_day", "value" => delivery_min_days },
          "maximum" => { "unit" => "business_day", "value" => delivery_max_days }
        },
        "active" => active,
        "metadata" => metadata
      }
    end

    def update_shipping_rate!(shipping_rate_id, display_name:, delivery_min_days:, delivery_max_days:, active:, metadata: {})
      {
        "id" => shipping_rate_id,
        "display_name" => display_name,
        "fixed_amount" => { "amount" => 1850, "currency" => "usd" },
        "delivery_estimate" => {
          "minimum" => { "unit" => "business_day", "value" => delivery_min_days },
          "maximum" => { "unit" => "business_day", "value" => delivery_max_days }
        },
        "active" => active,
        "metadata" => metadata
      }
    end

    def deactivate_shipping_rate!(shipping_rate_id)
      {
        "id" => shipping_rate_id,
        "display_name" => "USPS Ground Advantage",
        "fixed_amount" => { "amount" => 1850, "currency" => "usd" },
        "active" => false
      }
    end
  end

  setup do
    @admin = users(:admin)
    @user = users(:one)
    @provider = FakeProvider.new
  end

  def with_provider(provider)
    previous = Shipping.instance_variable_get(:@provider)
    Shipping.provider = provider
    yield
  ensure
    Shipping.provider = previous
  end

  test "non-admin users are redirected from shipping rates" do
    sign_in @user

    get admin_shipping_rates_url

    assert_redirected_to root_path
  end

  test "admin can create a shipping rate" do
    sign_in @admin

    params = {
      shipping_rate: {
        display_name: "USPS Ground Advantage",
        product_format: "framed",
        billing_basis: "per_item",
        amount: "18.50",
        currency: "usd",
        delivery_min_days: 2,
        delivery_max_days: 5,
        active: "1",
        default_rate: "1"
      }
    }

    with_provider(@provider) do
      assert_difference("ShippingRate.count", 1) do
        post admin_shipping_rates_url, params: params
      end
    end

    assert_redirected_to admin_shipping_rates_path
    assert_equal "framed", ShippingRate.last.product_format
  end

  test "admin can update a shipping rate" do
    sign_in @admin

    shipping_rate = ShippingRate.create!(
      stripe_shipping_rate_id: "shr_existing",
      stripe_shipping_rate_cache: {
        "id" => "shr_existing",
        "display_name" => "Old Rate",
        "fixed_amount" => { "amount" => 1850, "currency" => "usd" }
      },
      product_format: "framed",
      billing_basis: "per_item",
      active: true,
      default_rate: false
    )

    with_provider(@provider) do
      patch admin_shipping_rate_url(shipping_rate), params: {
        shipping_rate: {
          display_name: "Updated Rate",
          product_format: "framed",
          billing_basis: "per_item",
          amount: "18.50",
          currency: "usd",
          delivery_min_days: 2,
          delivery_max_days: 5,
          active: "1",
          default_rate: "0"
        }
      }
    end

    assert_redirected_to edit_admin_shipping_rate_path(shipping_rate)
    assert_equal "Updated Rate", shipping_rate.reload.stripe_shipping_rate_cache["display_name"]
  end

  test "admin can archive a shipping rate" do
    sign_in @admin

    shipping_rate = ShippingRate.create!(
      stripe_shipping_rate_id: "shr_archive",
      stripe_shipping_rate_cache: {
        "id" => "shr_archive",
        "display_name" => "Archive Rate",
        "fixed_amount" => { "amount" => 1850, "currency" => "usd" }
      },
      product_format: "framed",
      billing_basis: "per_item",
      active: true,
      default_rate: false
    )

    with_provider(@provider) do
      delete admin_shipping_rate_url(shipping_rate)
    end

    assert_redirected_to admin_shipping_rates_path
    assert_equal false, shipping_rate.reload.active
  end
end
