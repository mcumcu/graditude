require "test_helper"
require "ostruct"

class CheckoutSessionReconciliationJobTest < ActiveJob::TestCase
  test "reconciles checkout session status from stripe" do
    checkout_session = CheckoutSession.create!(status: :open, items: [ { price_id: "price_test", quantity: 1 } ], raw: {}, stripe_session_id: "cs_test")
    stripe_session = OpenStruct.new(id: "cs_test", status: "complete", payment_status: "paid", to_hash: { "id" => "cs_test", "status" => "complete", "payment_status" => "paid" })
    original_retrieve = Stripe::Checkout::Session.method(:retrieve)

    Stripe::Checkout::Session.define_singleton_method(:retrieve) do |_id|
      stripe_session
    end

    perform_enqueued_jobs do
      CheckoutSessionReconciliationJob.perform_now(checkout_session.id)
    end

    assert_equal "complete", checkout_session.reload.status
  ensure
    Stripe::Checkout::Session.define_singleton_method(:retrieve, original_retrieve)
  end
end
