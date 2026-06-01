require "test_helper"
require "ostruct"

class CheckoutSessionTest < ActiveSupport::TestCase
  test "ensure_order! creates one order for a completed checkout session" do
    user = users(:one)
    cart = Cart.create!(user: user, status: "completed")
    checkout_session = CheckoutSession.create!(
      cart: cart,
      status: :complete,
      items: [ { price_id: "price_test", quantity: 1 } ],
      raw: {},
      stripe_session_id: "cs_model_complete",
      shipping_details: {
        "stripe_shipping_details" => {
          "name" => "Floyd Miles",
          "address" => {
            "line1" => "7363 Cynthia Pass",
            "city" => "Toronto",
            "state" => "ON",
            "postal_code" => "N3Y 4H8",
            "country" => "CA"
          }
        }
      }
    )

    first_order = checkout_session.ensure_order!
    second_order = checkout_session.ensure_order!

    assert_equal first_order, second_order
    assert_equal 1, Order.where(checkout_session: checkout_session).count
    assert_equal user, first_order.user
    assert_equal "order_placed", first_order.status
    assert_equal "cs_model_complete", first_order.raw_hash.dig("checkout_session", "stripe_session_id")
    assert_equal "7363 Cynthia Pass", first_order.shipping_address_hash.dig("address", "line1")
  end

  test "updating checkout session shipping details syncs canonical order shipping address" do
    user = users(:one)
    cart = Cart.create!(user: user, status: "completed")
    checkout_session = CheckoutSession.create!(
      cart: cart,
      status: :complete,
      items: [ { price_id: "price_test", quantity: 1 } ],
      raw: {},
      stripe_session_id: "cs_model_shipping_sync"
    )

    order = checkout_session.ensure_order!

    checkout_session.update!(
      shipping_details: {
        "stripe_shipping_details" => {
          "name" => "Floyd Miles",
          "address" => {
            "line1" => "7363 Cynthia Pass",
            "city" => "Toronto",
            "state" => "ON",
            "postal_code" => "N3Y 4H8",
            "country" => "CA"
          }
        }
      }
    )

    assert_equal "7363 Cynthia Pass", order.reload.shipping_address_hash.dig("address", "line1")
  end

  test "ensure_order! falls back to stripe customer details when shipping details are absent" do
    user = users(:one)
    cart = Cart.create!(user: user, status: "completed")
    checkout_session = CheckoutSession.create!(
      cart: cart,
      status: :complete,
      items: [ { price_id: "price_test", quantity: 1 } ],
      raw: {
        "stripe_session" => {
          "customer_details" => {
            "name" => "Chris",
            "address" => {
              "line1" => "181 North Pottstown Pike",
              "city" => "Exton",
              "state" => "PA",
              "postal_code" => "19341",
              "country" => "US"
            }
          }
        }
      },
      stripe_session_id: "cs_model_customer_details"
    )

    order = checkout_session.ensure_order!

    assert_equal "stripe_customer_details", order.shipping_address_hash["source"]
    assert_equal "181 North Pottstown Pike", order.shipping_address_hash.dig("address", "line1")
    assert_equal "Chris", order.shipping_address_hash["name"]
  end

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
