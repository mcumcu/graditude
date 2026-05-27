require "test_helper"

class Shipping::CalculatorTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @cart = Cart.create!(user: @user, status: "open")
    @certificate = Certificate.create!(
      user: @user,
      graduate_name: "Graduate",
      honoree_name: "Honoree",
      degree: "B.S.",
      presented_on: "2026-05-15"
    )

    @framed_product = Product.create!(
      stripe_product_id: "prod_framed",
      stripe_product_cache: {
        "id" => "prod_framed",
        "metadata" => { "format" => "framed" }
      }
    )

    @unframed_product = Product.create!(
      stripe_product_id: "prod_unframed",
      stripe_product_cache: {
        "id" => "prod_unframed",
        "metadata" => { "format" => "unframed" }
      }
    )

    CertificateProduct.create!(
      cart: @cart,
      certificate: @certificate,
      product: @framed_product,
      stripe_price_id: "price_framed",
      quantity: 2,
      status: "pending"
    )

    CertificateProduct.create!(
      cart: @cart,
      certificate: @certificate,
      product: @unframed_product,
      stripe_price_id: "price_unframed",
      quantity: 3,
      status: "pending"
    )

    ShippingRate.create!(
      stripe_shipping_rate_id: "shr_framed",
      stripe_shipping_rate_cache: {
        "id" => "shr_framed",
        "display_name" => "USPS Ground Advantage",
        "fixed_amount" => { "amount" => 1850, "currency" => "usd" },
        "delivery_estimate" => { "minimum" => { "unit" => "business_day", "value" => 2 }, "maximum" => { "unit" => "business_day", "value" => 5 } }
      },
      product_format: "framed",
      billing_basis: "per_item",
      active: true,
      default_rate: true
    )

    ShippingRate.create!(
      stripe_shipping_rate_id: "shr_unframed",
      stripe_shipping_rate_cache: {
        "id" => "shr_unframed",
        "display_name" => "USPS Ground Advantage",
        "fixed_amount" => { "amount" => 1050, "currency" => "usd" },
        "delivery_estimate" => { "minimum" => { "unit" => "business_day", "value" => 2 }, "maximum" => { "unit" => "business_day", "value" => 5 } }
      },
      product_format: "unframed",
      billing_basis: "per_order",
      active: true,
      default_rate: true
    )
  end

  test "calculates framed per item and unframed per order" do
    result = Shipping::Calculator.new(cart: @cart).call

    assert_equal 2, result.line_items.size
    assert_equal 4750, result.total_cents
    assert_equal "usd", result.currency

    framed_item = result.line_items.find do |item|
      item.dig(:price_data, :product_data, :metadata, :product_format) == "framed"
    end
    assert_equal 2, framed_item[:quantity]

    unframed_item = result.line_items.find do |item|
      item.dig(:price_data, :product_data, :metadata, :product_format) == "unframed"
    end
    assert_equal 1, unframed_item[:quantity]
  end

  test "raises when a format is missing a rate" do
    ShippingRate.where(product_format: "unframed").delete_all

    assert_raises(Shipping::Calculator::MissingRateError) do
      Shipping::Calculator.new(cart: @cart).call
    end
  end
end
