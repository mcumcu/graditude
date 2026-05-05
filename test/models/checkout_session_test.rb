require "test_helper"
require "ostruct"

class CheckoutSessionTest < ActiveSupport::TestCase
  test "expire_in_stripe! expires open checkout session and updates local status" do
    checkout_session = CheckoutSession.create!(status: :open, items: [ { price_id: "price_test", quantity: 1 } ], raw: {}, stripe_session_id: "cs_model_expire")
    stripe_session = OpenStruct.new(id: "cs_model_expire", status: "expired", to_hash: { "id" => "cs_model_expire", "status" => "expired" })

    original_expire = Stripe::Checkout::Session.method(:expire)
    captured_opts = nil

    Stripe::Checkout::Session.define_singleton_method(:expire) do |_id, _params = {}, opts = {}|
      captured_opts = opts
      stripe_session
    end

    checkout_session.expire_in_stripe!

    assert_equal "checkout_session_expiration:#{checkout_session.id}", captured_opts[:idempotency_key]
    assert_equal "expired", checkout_session.reload.status
    assert_equal "cs_model_expire", checkout_session.raw_hash.dig("stripe_session_expired", "id")
  ensure
    Stripe::Checkout::Session.define_singleton_method(:expire, original_expire)
  end
end
