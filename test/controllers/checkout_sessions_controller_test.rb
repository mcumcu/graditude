require "test_helper"
require "ostruct"

class CheckoutSessionsControllerTest < ActionDispatch::IntegrationTest
  test "new renders checkout page for signed-in user" do
    user = users(:one)
    sign_in user

    product = Product.create!(title: "Graduation Gift", description: "Ceremony edition", price_cents: 3000, currency: "USD", details: {})
    price_map = StripePriceMap.create!(product: product, stripe_price_id: "price_test")
    cart = Cart.open_for(user)
    cart.certificate_products.create!(product: product, certificate: certificates(:one), stripe_price_map: price_map, quantity: 1)

    get new_checkout_url

    assert_response :success
    assert_select "h1", "Checkout"
    assert_select "button", "Start checkout"
  end

  test "create uses cart items for checkout" do
    user = users(:one)
    sign_in user

    product = Product.create!(title: "Graduation Gift", description: "Ceremony edition", price_cents: 3000, currency: "USD", details: {})
    price_map = StripePriceMap.create!(product: product, stripe_price_id: "price_test")
    cart = Cart.open_for(user)
    cart.certificate_products.create!(product: product, certificate: certificates(:one), stripe_price_map: price_map, quantity: 2)

    called_with = nil
    original_create = Stripe::Checkout::Session.method(:create)

    Stripe::Checkout::Session.define_singleton_method(:create) do |attrs|
      called_with = attrs
      OpenStruct.new(id: "cs_test")
    end

    post checkout_url

    assert_response :success
    assert_equal "price_test", called_with[:line_items].first[:price]
    assert_equal 2, called_with[:line_items].first[:quantity]
    assert_equal "cs_test", JSON.parse(response.body)["sessionId"]
  ensure
    Stripe::Checkout::Session.define_singleton_method(:create, original_create) if defined?(original_create) && original_create
  end

  test "create returns bad request when cart is empty" do
    sign_in users(:one)

    post checkout_url

    assert_response :bad_request
    assert_equal "cart is empty", JSON.parse(response.body)["error"]
  end

  test "show returns checkout session details" do
    checkout_session = CheckoutSession.create!(status: :open, items: [ { price_id: "price_test", quantity: 1 } ], raw: {}, stripe_session_id: "cs_show_test")

    get checkout_session_url(checkout_session), as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal checkout_session.id, body["id"]
    assert_equal "open", body["status"]
    assert_equal [], body["certificate_ids"]
  end

  test "create returns Stripe error as JSON when checkout session creation fails" do
    user = users(:one)
    sign_in user

    product = Product.create!(title: "Graduation Gift", description: "Ceremony edition", price_cents: 3000, currency: "USD", details: {})
    price_map = StripePriceMap.create!(product: product, stripe_price_id: "price_test")
    cart = Cart.open_for(user)
    cart.certificate_products.create!(product: product, certificate: certificates(:one), stripe_price_map: price_map, quantity: 1)

    original_create = Stripe::Checkout::Session.method(:create)

    Stripe::Checkout::Session.define_singleton_method(:create) do |_attrs|
      raise Stripe::StripeError.new("Expired API Key provided")
    end

    post checkout_url

    assert_response :bad_gateway
    assert_equal "Expired API Key provided", JSON.parse(response.body)["error"]
  ensure
    Stripe::Checkout::Session.define_singleton_method(:create, original_create) if defined?(original_create) && original_create
  end

  test "success page renders" do
    get checkout_success_url, params: { session_id: "cs_test_123" }

    assert_response :success
    assert_select "h1", "Payment complete"
    assert_select "strong", "cs_test_123"
    assert_select "a[href='mailto:support@thegraditude.com']"
  end

  test "cancel page renders" do
    get checkout_cancel_url

    assert_response :success
    assert_select "h1", "Checkout canceled"
    assert_select "a[href='mailto:support@thegraditude.com']"
  end
end
