require "test_helper"
require "ostruct"

class StripePriceMapTest < ActiveSupport::TestCase
  test "unit_amount_cents and currency come from Stripe price object" do
    product = Product.create!(title: "Dummy Product")
    price_map = StripePriceMap.create!(product: product, stripe_price_id: "price_test_runtime")

    stripe_price = OpenStruct.new(unit_amount: 4500, currency: "usd")
    original_retrieve = Stripe::Price.method(:retrieve)
    Stripe::Price.define_singleton_method(:retrieve) { |stripe_price_id| stripe_price }

    begin
      assert_equal 4500, price_map.unit_amount_cents
      assert_equal "usd", price_map.currency
    ensure
      Stripe::Price.define_singleton_method(:retrieve, original_retrieve)
    end
  end
end
