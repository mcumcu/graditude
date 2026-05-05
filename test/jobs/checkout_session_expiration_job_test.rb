require "test_helper"
require "ostruct"

class CheckoutSessionExpirationJobTest < ActiveJob::TestCase
  test "expires an open checkout session in stripe and updates status" do
    checkout_session = CheckoutSession.create!(status: :open, items: [ { price_id: "price_test", quantity: 1 } ], raw: {}, stripe_session_id: "cs_expire_test")
    stripe_session = OpenStruct.new(id: "cs_expire_test", status: "expired", to_hash: { "id" => "cs_expire_test", "status" => "expired" })

    original_expire = Stripe::Checkout::Session.method(:expire)
    Stripe::Checkout::Session.define_singleton_method(:expire) do |_id, _params = {}, _opts = {}|
      stripe_session
    end

    perform_enqueued_jobs do
      CheckoutSessionExpirationJob.perform_now(checkout_session.id)
    end

    assert_equal "expired", checkout_session.reload.status
    assert_equal "cs_expire_test", checkout_session.raw_hash.dig("stripe_session_expired", "id")
  ensure
    Stripe::Checkout::Session.define_singleton_method(:expire, original_expire)
  end
end
