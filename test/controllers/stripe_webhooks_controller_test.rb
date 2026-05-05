require "test_helper"
require "ostruct"

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
    assert_equal "checkout.session.expired", checkout_session.reload.raw["stripe_event"]["type"]
    assert_equal "cs_test_expired", checkout_session.reload.raw["stripe_session"]["id"]
  ensure
    Stripe::Webhook.define_singleton_method(:construct_event, original_construct_event)
  end

  test "expired webhook merges stripe event payload into existing raw data" do
    checkout_session = CheckoutSession.create!(status: :open, items: [ { price_id: "price_test", quantity: 1 } ], raw: { "original_note" => "keep" }, stripe_session_id: "cs_test_expired_merge")
    event = OpenStruct.new(
      type: "checkout.session.expired",
      data: OpenStruct.new(object: OpenStruct.new(id: "cs_test_expired_merge", to_hash: { "id" => "cs_test_expired_merge" })),
      to_hash: { "type" => "checkout.session.expired" }
    )

    original_construct_event = Stripe::Webhook.method(:construct_event)
    Stripe::Webhook.define_singleton_method(:construct_event) do |_payload, _sig_header, _secret|
      event
    end

    post "/stripe/webhook", headers: { "HTTP_STRIPE_SIGNATURE" => "tst" }, params: "{}"

    assert_response :success
    reloaded = checkout_session.reload
    assert_equal "keep", reloaded.raw["original_note"]
    assert_equal "checkout.session.expired", reloaded.raw["stripe_event"]["type"]
    assert_equal "cs_test_expired_merge", reloaded.raw["stripe_session"]["id"]
    assert_equal "expired", reloaded.status
  ensure
    Stripe::Webhook.define_singleton_method(:construct_event, original_construct_event)
  end

  test "invalid webhook signature still returns success" do
    checkout_session = CheckoutSession.create!(status: :open, items: [ { price_id: "price_test", quantity: 1 } ], raw: {}, stripe_session_id: "cs_test_invalid_signature")

    original_construct_event = Stripe::Webhook.method(:construct_event)
    Stripe::Webhook.define_singleton_method(:construct_event) do |_payload, _sig_header, _secret|
      raise Stripe::SignatureVerificationError.new("Invalid signature", "bad_sig")
    end

    post "/stripe/webhook", headers: { "HTTP_STRIPE_SIGNATURE" => "bad_sig" }, params: "{}"

    assert_response :success
    assert_equal "open", checkout_session.reload.status
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

  test "product.updated webhook refreshes stripe_product_cache" do
    product = Product.create!(stripe_product_id: "prod_test_webhook")
    raw_product = {
      "id" => "prod_test_webhook",
      "name" => "Updated Stripe Product",
      "description" => "Updated Stripe description",
      "metadata" => { "certificate_templates" => "boulder,westtown" }
    }
    product_object = OpenStruct.new(id: "prod_test_webhook", to_hash: raw_product)
    event = OpenStruct.new(
      type: "product.updated",
      data: OpenStruct.new(object: product_object),
      to_hash: { "type" => "product.updated" }
    )

    original_construct_event = Stripe::Webhook.method(:construct_event)
    Stripe::Webhook.define_singleton_method(:construct_event) do |_payload, _sig_header, _secret|
      event
    end

    Rails.cache.delete(product.send(:stripe_product_cache_key))

    post "/stripe/webhook", headers: { "HTTP_STRIPE_SIGNATURE" => "tst" }, params: "{}"

    assert_response :success
    assert_equal "Updated Stripe Product", product.reload.stripe_product_cache["name"]
  ensure
    if original_construct_event
      Stripe::Webhook.define_singleton_method(:construct_event, original_construct_event.to_proc)
    end
  end
end
