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
    assert_select "button", "Start secure checkout"
  end

  test "create uses cart items for checkout" do
    user = users(:one)
    sign_in user

    product = Product.create!(title: "Graduation Gift", description: "Ceremony edition", price_cents: 3000, currency: "USD", details: {})
    price_map = StripePriceMap.create!(product: product, stripe_price_id: "price_test")
    cart = Cart.open_for(user)
    cart.certificate_products.create!(product: product, certificate: certificates(:one), stripe_price_map: price_map, quantity: 2)

    called_with = nil
    fake_session_resource = Object.new
    fake_session_resource.define_singleton_method(:create) do |attrs|
      called_with = attrs
      OpenStruct.new(id: "cs_test", client_secret: "cs_test_secret", url: "https://checkout.test/session/cs_test")
    end
    fake_checkout = OpenStruct.new(sessions: fake_session_resource)
    fake_client = Object.new
    fake_client.define_singleton_method(:v1) { OpenStruct.new(checkout: fake_checkout) }

    original_new = Stripe::StripeClient.singleton_class.instance_method(:new)
    Stripe::StripeClient.singleton_class.send(:define_method, :new) do |*args, **kwargs, &block|
      fake_client
    end

    begin
      post checkout_url
    ensure
      Stripe::StripeClient.singleton_class.send(:define_method, :new, original_new)
    end

    assert_response :success
    assert_equal "payment", called_with[:mode]
    assert_equal 2, called_with[:line_items].first[:quantity]
    assert_equal [ "card" ], called_with[:payment_method_types]
    assert_equal "required", called_with[:billing_address_collection]
    assert_equal [ "US", "CA" ], called_with[:shipping_address_collection][:allowed_countries]
    assert_includes called_with[:success_url], "/checkout/success?session_id={CHECKOUT_SESSION_ID}"
    assert_includes called_with[:cancel_url], "/checkout/cancel?session_id={CHECKOUT_SESSION_ID}"

    first_line_item = called_with[:line_items].first
    assert_equal "price_test", first_line_item[:price]
    assert_equal 2, first_line_item[:quantity]
    assert_nil first_line_item[:price_data]

    assert_equal "cs_test", JSON.parse(response.body)["sessionId"]
    assert_equal "https://checkout.test/session/cs_test", JSON.parse(response.body)["url"]
  end

  test "create uses configured payment method types" do
    user = users(:one)
    sign_in user

    original_types = ENV["STRIPE_CHECKOUT_PAYMENT_METHOD_TYPES"]
    ENV["STRIPE_CHECKOUT_PAYMENT_METHOD_TYPES"] = "card, us_bank_account, link"

    product = Product.create!(title: "Graduation Gift", description: "Ceremony edition", price_cents: 3000, currency: "USD", details: {})
    price_map = StripePriceMap.create!(product: product, stripe_price_id: "price_test")
    cart = Cart.open_for(user)
    cart.certificate_products.create!(product: product, certificate: certificates(:one), stripe_price_map: price_map, quantity: 1)

    called_with = nil
    fake_session_resource = Object.new
    fake_session_resource.define_singleton_method(:create) do |attrs|
      called_with = attrs
      OpenStruct.new(id: "cs_test", client_secret: "cs_test_secret", url: "https://checkout.test/session/cs_test")
    end
    fake_checkout = OpenStruct.new(sessions: fake_session_resource)
    fake_client = Object.new
    fake_client.define_singleton_method(:v1) { OpenStruct.new(checkout: fake_checkout) }

    original_new = Stripe::StripeClient.singleton_class.instance_method(:new)
    Stripe::StripeClient.singleton_class.send(:define_method, :new) do |*args, **kwargs, &block|
      fake_client
    end

    begin
      post checkout_url
    ensure
      Stripe::StripeClient.singleton_class.send(:define_method, :new, original_new)
    end

    assert_response :success
    assert_equal [ "card", "us_bank_account", "link" ], called_with[:payment_method_types]
    assert_equal "payment", called_with[:mode]
  ensure
    ENV["STRIPE_CHECKOUT_PAYMENT_METHOD_TYPES"] = original_types
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

    fake_session_resource = Object.new
    fake_session_resource.define_singleton_method(:create) do |_attrs|
      raise Stripe::StripeError.new("Expired API Key provided")
    end
    fake_checkout = OpenStruct.new(sessions: fake_session_resource)
    fake_client = Object.new
    fake_client.define_singleton_method(:v1) { OpenStruct.new(checkout: fake_checkout) }

    original_new = Stripe::StripeClient.singleton_class.instance_method(:new)
    Stripe::StripeClient.singleton_class.send(:define_method, :new) do |*args, **kwargs, &block|
      fake_client
    end

    begin
      post checkout_url
    ensure
      Stripe::StripeClient.singleton_class.send(:define_method, :new, original_new)
    end

    assert_response :bad_gateway
    assert_equal "Expired API Key provided", JSON.parse(response.body)["error"]
  end

  test "success redirects to cancel when session_id is missing" do
    get checkout_success_url

    assert_redirected_to checkout_cancel_path
  end

  test "success redirects to cancel when session_id does not match any checkout session" do
    get checkout_success_url, params: { session_id: "cs_unknown_xyz" }

    assert_redirected_to checkout_cancel_path
  end

  test "success page renders for complete checkout session" do
    CheckoutSession.create!(status: :complete, items: [ { price_id: "price_test", quantity: 1 } ], raw: {}, stripe_session_id: "cs_test_123")

    get checkout_success_url, params: { session_id: "cs_test_123" }

    assert_response :success
    assert_select "h1", "Payment complete"
    assert_select "strong", "cs_test_123"
    assert_select "a[href='mailto:support@thegraditude.com']"
  end

  test "success redirects to cancel for failed checkout session" do
    CheckoutSession.create!(status: :failed, items: [ { price_id: "price_test", quantity: 1 } ], raw: {}, stripe_session_id: "cs_test_failed")

    get checkout_success_url, params: { session_id: "cs_test_failed" }

    assert_redirected_to checkout_cancel_path(session_id: "cs_test_failed", outcome: "failed")
  end

  test "success redirects to cancel for expired checkout session" do
    CheckoutSession.create!(status: :expired, items: [ { price_id: "price_test", quantity: 1 } ], raw: {}, stripe_session_id: "cs_test_expired")

    get checkout_success_url, params: { session_id: "cs_test_expired" }

    assert_redirected_to checkout_cancel_path(session_id: "cs_test_expired", outcome: "expired")
  end

  test "cancel page renders" do
    get checkout_cancel_url

    assert_response :success
    assert_select "h1", "Checkout canceled"
    assert_select "span.font-semibold", "Canceled"
    assert_select "a[href='mailto:support@thegraditude.com']"
  end

  test "cancel page shows async payment failed badge" do
    get checkout_cancel_url, params: { outcome: "failed", session_id: "cs_async_failed_123" }

    assert_response :success
    assert_select "h1", "Payment not completed"
    assert_select "span.font-semibold", "Async payment failed"
  end

  test "cancel page shows expired badge" do
    get checkout_cancel_url, params: { outcome: "expired", session_id: "cs_expired_123" }

    assert_response :success
    assert_select "h1", "Checkout session expired"
    assert_select "span.font-semibold", "Expired"
  end
end
