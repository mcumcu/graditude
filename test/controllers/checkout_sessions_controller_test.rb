require "test_helper"
require "ostruct"

class CheckoutSessionsControllerTest < ActionDispatch::IntegrationTest
  test "new renders checkout page for signed-in user" do
    user = users(:one)
    sign_in user

    product = Product.create!(stripe_product_id: "prod_test")
    cart = Cart.open_for(user)
    cart.certificate_products.create!(product: product, certificate: certificates(:one), stripe_price_id: "price_test", quantity: 1)

    stripe_product = OpenStruct.new(
      id: "prod_test",
      name: "Graduation Gift",
      description: "Ceremony edition",
      metadata: {},
      default_price: "price_test_default",
      to_hash: {
        "id" => "prod_test",
        "name" => "Graduation Gift",
        "description" => "Ceremony edition",
        "metadata" => {},
        "default_price" => "price_test_default"
      }
    )
    stripe_price = OpenStruct.new(unit_amount: 3000, currency: "usd")

    stub_stripe_product_and_price_retrieve(stripe_product, stripe_price) do
      get new_checkout_url
    end

    assert_response :success
    assert_select "h1", "Checkout"
    assert_select "button", "Start secure checkout"
  end

  test "create uses cart items for checkout" do
    user = users(:one)
    sign_in user

    product = Product.create!(stripe_product_id: "prod_test")
    cart = Cart.open_for(user)
    cart.certificate_products.create!(product: product, certificate: certificates(:one), stripe_price_id: "price_test", quantity: 2)

    stripe_product = OpenStruct.new(
      id: "prod_test",
      name: "Graduation Gift",
      description: "Ceremony edition",
      metadata: {},
      default_price: "price_test_default",
      to_hash: {
        "id" => "prod_test",
        "name" => "Graduation Gift",
        "description" => "Ceremony edition",
        "metadata" => {},
        "default_price" => "price_test_default"
      }
    )
    stripe_price = OpenStruct.new(unit_amount: 3000, currency: "usd")

    stub_stripe_product_and_price_retrieve(stripe_product, stripe_price) do
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
  end

  test "expires previous open checkout sessions before creating a new session" do
    user = users(:one)
    sign_in user

    product = Product.create!(stripe_product_id: "prod_test")
    cart = Cart.open_for(user)
    previous_session = cart.checkout_sessions.create!(status: :open, items: [ { price_id: "price_test", quantity: 1 } ], raw: {}, stripe_session_id: "cs_prior_test")
    cart.certificate_products.create!(product: product, certificate: certificates(:one), stripe_price_id: "price_test", quantity: 1)

    stripe_product = OpenStruct.new(
      id: "prod_test",
      name: "Graduation Gift",
      description: "Ceremony edition",
      metadata: {},
      default_price: "price_test_default",
      to_hash: {
        "id" => "prod_test",
        "name" => "Graduation Gift",
        "description" => "Ceremony edition",
        "metadata" => {},
        "default_price" => "price_test_default"
      }
    )
    stripe_price = OpenStruct.new(unit_amount: 3000, currency: "usd")

    stub_stripe_product_and_price_retrieve(stripe_product, stripe_price) do
      expire_called = false
      expired_id = nil
      original_expire = Stripe::Checkout::Session.method(:expire)
      Stripe::Checkout::Session.define_singleton_method(:expire) do |id, params = {}|
        expired_id = id
        expire_called = true
        OpenStruct.new(id: id, status: "expired", to_hash: { "id" => id, "status" => "expired" })
      end

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
        Stripe::Checkout::Session.define_singleton_method(:expire, original_expire)
      end

      assert_response :success
      assert_equal true, expire_called
      assert_equal "cs_prior_test", expired_id
      assert_equal "expired", previous_session.reload.status
      assert_equal 0, enqueued_jobs.count { |job| job[:job] == CheckoutSessionExpirationJob && job[:args] == [ previous_session.id ] }
      assert_equal "cs_test", JSON.parse(response.body)["sessionId"]
    end
  end

  test "create uses configured payment method types" do
    user = users(:one)
    sign_in user

    original_types = ENV["STRIPE_CHECKOUT_PAYMENT_METHOD_TYPES"]
    ENV["STRIPE_CHECKOUT_PAYMENT_METHOD_TYPES"] = "card, us_bank_account, link"

    product = Product.create!(stripe_product_id: "prod_test")
    cart = Cart.open_for(user)
    cart.certificate_products.create!(product: product, certificate: certificates(:one), stripe_price_id: "price_test", quantity: 1)

    stripe_product = OpenStruct.new(
      id: "prod_test",
      name: "Graduation Gift",
      description: "Ceremony edition",
      metadata: {},
      default_price: "price_test_default",
      to_hash: {
        "id" => "prod_test",
        "name" => "Graduation Gift",
        "description" => "Ceremony edition",
        "metadata" => {},
        "default_price" => "price_test_default"
      }
    )
    stripe_price = OpenStruct.new(unit_amount: 3000, currency: "usd")

    stub_stripe_product_and_price_retrieve(stripe_product, stripe_price) do
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
    end
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

    product = Product.create!(stripe_product_id: "prod_test")
    cart = Cart.open_for(user)
    cart.certificate_products.create!(product: product, certificate: certificates(:one), stripe_price_id: "price_test", quantity: 1)

    stripe_product = OpenStruct.new(
      id: "prod_test",
      name: "Graduation Gift",
      description: "Ceremony edition",
      metadata: {},
      default_price: "price_test_default",
      to_hash: {
        "id" => "prod_test",
        "name" => "Graduation Gift",
        "description" => "Ceremony edition",
        "metadata" => {},
        "default_price" => "price_test_default"
      }
    )
    stripe_price = OpenStruct.new(unit_amount: 3000, currency: "usd")

    stub_stripe_product_and_price_retrieve(stripe_product, stripe_price) do
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
