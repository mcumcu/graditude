require "test_helper"
require "ostruct"

class PriceTest < ActiveSupport::TestCase
  test "stripe_price_data caches stripe price payload in stripe_price_cache and Rails cache" do
    product = Product.create!(stripe_product_id: "prod_test_price")
    price = product.prices.create!(stripe_price_id: "price_test_cache")
    stripe_price = OpenStruct.new(
      id: "price_test_cache",
      unit_amount: 4200,
      currency: "usd",
      to_hash: {
        "id" => "price_test_cache",
        "unit_amount" => 4200,
        "currency" => "usd"
      }
    )

    original_retrieve = Stripe::Price.method(:retrieve)
    Stripe::Price.define_singleton_method(:retrieve) { |_price_id| stripe_price }

    Rails.cache.delete(price.send(:stripe_price_cache_key))

    price_data = price.stripe_price_data

    assert_equal 4200, price_data["unit_amount"]
    assert_equal "usd", price_data["currency"]
    assert_equal 4200, price.stripe_price_amount_cents
    assert_equal "usd", price.stripe_price_currency
    assert_equal "usd", price.reload.stripe_price_cache["currency"]
  ensure
    Stripe::Price.define_singleton_method(:retrieve, original_retrieve.to_proc) if original_retrieve
  end

  test "stripe_price_data reloads and refreshes persisted cache" do
    product = Product.create!(stripe_product_id: "prod_test_price_reload")
    price = product.prices.create!(stripe_price_id: "price_test_reload", stripe_price_cache: { "unit_amount" => 3500, "currency" => "usd" })
    stripe_price = OpenStruct.new(
      id: "price_test_reload",
      unit_amount: 3800,
      currency: "usd",
      to_hash: {
        "id" => "price_test_reload",
        "unit_amount" => 3800,
        "currency" => "usd"
      }
    )

    original_retrieve = Stripe::Price.method(:retrieve)
    Stripe::Price.define_singleton_method(:retrieve) { |_price_id| stripe_price }

    reloaded = price.stripe_price_data(reload: true)

    assert_equal 3800, reloaded["unit_amount"]
    assert_equal 3800, price.reload.stripe_price_cache["unit_amount"]
  ensure
    Stripe::Price.define_singleton_method(:retrieve, original_retrieve.to_proc) if original_retrieve
  end

  test "clear_stripe_price_cache! removes both Rails cache and persisted stripe_price_cache" do
    product = Product.create!(stripe_product_id: "prod_test_price_clear")
    price = product.prices.create!(stripe_price_id: "price_test_clear", stripe_price_cache: { "unit_amount" => 5000, "currency" => "usd" })
    Rails.cache.write(price.send(:stripe_price_cache_key), price.stripe_price_cache)

    assert_equal({ "unit_amount" => 5000, "currency" => "usd" }, price.reload.stripe_price_cache)

    price.clear_stripe_price_cache!

    assert_nil Rails.cache.read(price.send(:stripe_price_cache_key))
    assert_equal({}, price.reload.stripe_price_cache)
  end
end
