require "test_helper"

class StripeWebhooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_stripe_webhook_secret = ENV["STRIPE_WEBHOOK_SECRET"]
    ENV["STRIPE_WEBHOOK_SECRET"] = "whsec_test"
  end

  teardown do
    ENV["STRIPE_WEBHOOK_SECRET"] = @original_stripe_webhook_secret
  end

  test "checkout session completed webhook updates checkout session status" do
    checkout_session = CheckoutSession.create!(status: :open, items: [ { price_id: "price_test", quantity: 1 } ], raw: {}, stripe_session_id: "cs_test")
    event = OpenStruct.new(
      type: "checkout.session.completed",
      data: OpenStruct.new(object: OpenStruct.new(id: "cs_test", to_hash: { "id" => "cs_test" })),
      to_hash: { "type" => "checkout.session.completed" }
    )

    original_construct_event = Stripe::Webhook.method(:construct_event)
    Stripe::Webhook.define_singleton_method(:construct_event) do |_payload, _sig_header, _secret|
      event
    end

    post "/stripe/webhook", headers: { "HTTP_STRIPE_SIGNATURE" => "tst" }, params: "{}"

    assert_response :success
    assert_equal "complete", checkout_session.reload.status
  ensure
    Stripe::Webhook.define_singleton_method(:construct_event, original_construct_event)
  end

  test "expired webhook updates checkout session status" do
    checkout_session = CheckoutSession.create!(status: :open, items: [ { price_id: "price_test", quantity: 1 } ], raw: {}, stripe_session_id: "cs_test_expired")
    event = OpenStruct.new(
      type: "checkout.session.expired",
      data: OpenStruct.new(object: OpenStruct.new(id: "cs_test_expired", to_hash: { "id" => "cs_test_expired" })),
      to_hash: { "type" => "checkout.session.expired" }
    )

    original_construct_event = Stripe::Webhook.method(:construct_event)
    Stripe::Webhook.define_singleton_method(:construct_event) do |_payload, _sig_header, _secret|
      event
    end

    post "/stripe/webhook", headers: { "HTTP_STRIPE_SIGNATURE" => "tst" }, params: "{}"

    assert_response :success
    assert_equal "expired", checkout_session.reload.status
  ensure
    Stripe::Webhook.define_singleton_method(:construct_event, original_construct_event)
  end

  test "async payment succeeded webhook updates checkout session status" do
    checkout_session = CheckoutSession.create!(status: :open, items: [ { price_id: "price_test", quantity: 1 } ], raw: {}, stripe_session_id: "cs_test_async")
    event = OpenStruct.new(
      type: "checkout.session.async_payment_succeeded",
      data: OpenStruct.new(object: OpenStruct.new(id: "cs_test_async", to_hash: { "id" => "cs_test_async" })),
      to_hash: { "type" => "checkout.session.async_payment_succeeded" }
    )

    original_construct_event = Stripe::Webhook.method(:construct_event)
    Stripe::Webhook.define_singleton_method(:construct_event) do |_payload, _sig_header, _secret|
      event
    end

    post "/stripe/webhook", headers: { "HTTP_STRIPE_SIGNATURE" => "tst" }, params: "{}"

    assert_response :success
    assert_equal "complete", checkout_session.reload.status
  ensure
    Stripe::Webhook.define_singleton_method(:construct_event, original_construct_event)
  end
end
