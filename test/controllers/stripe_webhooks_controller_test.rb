require "test_helper"
require "ostruct"

class StripeWebhooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_stripe_webhook_secret = ENV["STRIPE_WEBHOOK_SECRET"]
    ENV["STRIPE_WEBHOOK_SECRET"] = "whsec_test"
    start_stubbed_stripe_products_for_webhooks
  end

  teardown do
    ENV["STRIPE_WEBHOOK_SECRET"] = @original_stripe_webhook_secret
    stop_stubbed_stripe_products_for_webhooks
  end

  test "checkout session completed webhook updates checkout session status" do
    cart = Cart.create!(user: users(:one), status: "completed")
    checkout_session = CheckoutSession.create!(cart: cart, status: :open, items: [ { price_id: "price_test", quantity: 1 } ], raw: {}, stripe_session_id: "cs_test")
    event = OpenStruct.new(
      type: "checkout.session.completed",
      data: OpenStruct.new(object: OpenStruct.new(id: "cs_test", to_hash: { "id" => "cs_test" })),
      to_hash: { "type" => "checkout.session.completed" }
    )

    original_construct_event = Stripe::Webhook.method(:construct_event)
    Stripe::Webhook.define_singleton_method(:construct_event) do |_payload, _sig_header, _secret|
      event
    end

    without_catalog_broadcasts do
      post "/stripe/webhook", headers: { "HTTP_STRIPE_SIGNATURE" => "tst" }, params: "{}"
    end

    assert_response :success
    assert_equal "complete", checkout_session.reload.status
    assert_equal "order_placed", checkout_session.reload.order&.status
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

    without_catalog_broadcasts do
      post "/stripe/webhook", headers: { "HTTP_STRIPE_SIGNATURE" => "tst" }, params: "{}"
    end

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

    without_catalog_broadcasts do
      post "/stripe/webhook", headers: { "HTTP_STRIPE_SIGNATURE" => "tst" }, params: "{}"
    end

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
    cart = Cart.create!(user: users(:one), status: "completed")
    checkout_session = CheckoutSession.create!(cart: cart, status: :open, items: [ { price_id: "price_test", quantity: 1 } ], raw: {}, stripe_session_id: "cs_test_async")
    event = OpenStruct.new(
      type: "checkout.session.async_payment_succeeded",
      data: OpenStruct.new(object: OpenStruct.new(id: "cs_test_async", to_hash: { "id" => "cs_test_async" })),
      to_hash: { "type" => "checkout.session.async_payment_succeeded" }
    )

    original_construct_event = Stripe::Webhook.method(:construct_event)
    Stripe::Webhook.define_singleton_method(:construct_event) do |_payload, _sig_header, _secret|
      event
    end

    without_catalog_broadcasts do
      post "/stripe/webhook", headers: { "HTTP_STRIPE_SIGNATURE" => "tst" }, params: "{}"
    end

    assert_response :success
    assert_equal "complete", checkout_session.reload.status
    assert_equal "order_placed", checkout_session.reload.order&.status
  ensure
    Stripe::Webhook.define_singleton_method(:construct_event, original_construct_event)
  end

  test "charge refunded webhook captures stripe payload on related order" do
    cart = Cart.create!(user: users(:one), status: "completed")
    checkout_session = CheckoutSession.create!(
      cart: cart,
      status: :complete,
      items: [ { price_id: "price_test", quantity: 1 } ],
      raw: { "stripe_session" => { "payment_intent" => "pi_refunded_test" } },
      stripe_session_id: "cs_refunded"
    )
    order = checkout_session.ensure_order!
    event = OpenStruct.new(
      type: "charge.refunded",
      data: OpenStruct.new(object: OpenStruct.new(id: "ch_refunded_test", payment_intent: "pi_refunded_test", to_hash: { "id" => "ch_refunded_test", "payment_intent" => "pi_refunded_test" })),
      to_hash: { "type" => "charge.refunded" }
    )

    original_construct_event = Stripe::Webhook.method(:construct_event)
    Stripe::Webhook.define_singleton_method(:construct_event) do |_payload, _sig_header, _secret|
      event
    end

    without_catalog_broadcasts do
      post "/stripe/webhook", headers: { "HTTP_STRIPE_SIGNATURE" => "tst" }, params: "{}"
    end

    assert_response :success
    assert_equal "charge.refunded", order.reload.raw.dig("stripe_events", "charge.refunded", "type")
    assert_equal "order_placed", order.status
  ensure
    Stripe::Webhook.define_singleton_method(:construct_event, original_construct_event)
  end

  test "payment intent canceled webhook captures stripe payload on related order" do
    cart = Cart.create!(user: users(:one), status: "completed")
    checkout_session = CheckoutSession.create!(
      cart: cart,
      status: :complete,
      items: [ { price_id: "price_test", quantity: 1 } ],
      raw: { "stripe_session" => { "payment_intent" => "pi_canceled_test" } },
      stripe_session_id: "cs_canceled"
    )
    order = checkout_session.ensure_order!
    event = OpenStruct.new(
      type: "payment_intent.canceled",
      data: OpenStruct.new(object: OpenStruct.new(id: "pi_canceled_test", to_hash: { "id" => "pi_canceled_test", "object" => "payment_intent" })),
      to_hash: { "type" => "payment_intent.canceled" }
    )

    original_construct_event = Stripe::Webhook.method(:construct_event)
    Stripe::Webhook.define_singleton_method(:construct_event) do |_payload, _sig_header, _secret|
      event
    end

    without_catalog_broadcasts do
      post "/stripe/webhook", headers: { "HTTP_STRIPE_SIGNATURE" => "tst" }, params: "{}"
    end

    assert_response :success
    assert_equal "payment_intent.canceled", order.reload.raw.dig("stripe_events", "payment_intent.canceled", "type")
    assert_equal "order_placed", order.status
  ensure
    Stripe::Webhook.define_singleton_method(:construct_event, original_construct_event)
  end

  test "product.updated webhook refreshes stripe_product_cache" do
    product = Product.create!(stripe_product_id: "prod_test_webhook")
    raw_product = {
      "id" => "prod_test_webhook",
      "name" => "Updated Stripe Product",
      "description" => "Updated Stripe description",
      "metadata" => { "certificate_templates" => "boulder,westtown", "format" => "framed" }
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

    without_catalog_broadcasts do
      post "/stripe/webhook", headers: { "HTTP_STRIPE_SIGNATURE" => "tst" }, params: "{}"
    end

    assert_response :success
    assert_equal "Updated Stripe Product", product.reload.stripe_product_cache["name"]
  ensure
    if original_construct_event
      Stripe::Webhook.define_singleton_method(:construct_event, original_construct_event.to_proc)
    end
  end

  test "price.updated webhook refreshes stripe_price_cache" do
    product = Product.create!(
      stripe_product_id: "prod_price_webhook",
      stripe_product_cache: {
        "id" => "prod_price_webhook",
        "default_price" => "price_webhook",
        "metadata" => { "format" => "framed" }
      }
    )
    price = product.prices.create!(stripe_price_id: "price_webhook", stripe_price_cache: { "unit_amount" => 1000, "currency" => "usd" })

    price_object = OpenStruct.new(
      id: "price_webhook",
      product: "prod_price_webhook",
      to_hash: { "id" => "price_webhook", "unit_amount" => 2500, "currency" => "usd", "product" => "prod_price_webhook" }
    )
    event = OpenStruct.new(
      type: "price.updated",
      data: OpenStruct.new(object: price_object),
      to_hash: { "type" => "price.updated" }
    )

    original_construct_event = Stripe::Webhook.method(:construct_event)
    Stripe::Webhook.define_singleton_method(:construct_event) do |_payload, _sig_header, _secret|
      event
    end

    without_catalog_broadcasts do
      post "/stripe/webhook", headers: { "HTTP_STRIPE_SIGNATURE" => "tst" }, params: "{}"
    end

    assert_response :success
    assert_equal 2500, price.reload.stripe_price_cache["unit_amount"]
  ensure
    if original_construct_event
      Stripe::Webhook.define_singleton_method(:construct_event, original_construct_event.to_proc)
    end
  end

  test "price.deleted webhook clears price cache" do
    product = Product.create!(
      stripe_product_id: "prod_price_deleted",
      stripe_product_cache: {
        "id" => "prod_price_deleted",
        "default_price" => "price_deleted",
        "metadata" => { "format" => "framed" }
      }
    )
    price = product.prices.create!(stripe_price_id: "price_deleted", stripe_price_cache: { "unit_amount" => 1200, "currency" => "usd" })

    price_object = OpenStruct.new(
      id: "price_deleted",
      product: "prod_price_deleted",
      to_hash: { "id" => "price_deleted", "product" => "prod_price_deleted" }
    )
    event = OpenStruct.new(
      type: "price.deleted",
      data: OpenStruct.new(object: price_object),
      to_hash: { "type" => "price.deleted" }
    )

    original_construct_event = Stripe::Webhook.method(:construct_event)
    Stripe::Webhook.define_singleton_method(:construct_event) do |_payload, _sig_header, _secret|
      event
    end

    without_catalog_broadcasts do
      post "/stripe/webhook", headers: { "HTTP_STRIPE_SIGNATURE" => "tst" }, params: "{}"
    end

    assert_response :success
    assert_equal({}, price.reload.stripe_price_cache)
  ensure
    if original_construct_event
      Stripe::Webhook.define_singleton_method(:construct_event, original_construct_event.to_proc)
    end
  end

  private

  def without_catalog_broadcasts
    original_updated = Catalog::Broadcasts.method(:product_updated)
    original_created = Catalog::Broadcasts.method(:product_created)
    original_removed = Catalog::Broadcasts.method(:product_removed)

    Catalog::Broadcasts.define_singleton_method(:product_updated) { |_product| }
    Catalog::Broadcasts.define_singleton_method(:product_created) { |_product| }
    Catalog::Broadcasts.define_singleton_method(:product_removed) { |_product| }

    yield
  ensure
    Catalog::Broadcasts.define_singleton_method(:product_updated, original_updated.to_proc) if original_updated
    Catalog::Broadcasts.define_singleton_method(:product_created, original_created.to_proc) if original_created
    Catalog::Broadcasts.define_singleton_method(:product_removed, original_removed.to_proc) if original_removed
  end
end
