require "test_helper"
require "ostruct"
require "base64"
require "uri"

class CheckoutSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ShippingRate.create!(
      stripe_shipping_rate_id: "shr_framed_test",
      stripe_shipping_rate_cache: {
        "id" => "shr_framed_test",
        "display_name" => "USPS Ground Advantage",
        "fixed_amount" => { "amount" => 1850, "currency" => "usd" }
      },
      product_format: "framed",
      billing_basis: "per_item",
      active: true,
      default_rate: true
    )
  end

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
      metadata: { "format" => "framed" },
      default_price: "price_test_default",
      to_hash: {
        "id" => "prod_test",
        "name" => "Graduation Gift",
        "description" => "Ceremony edition",
        "metadata" => { "format" => "framed" },
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
      metadata: { "format" => "framed" },
      default_price: "price_test_default",
      to_hash: {
        "id" => "prod_test",
        "name" => "Graduation Gift",
        "description" => "Ceremony edition",
        "metadata" => { "format" => "framed" },
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
      success_uri = URI.parse(called_with[:success_url])
      cancel_uri = URI.parse(called_with[:cancel_url])

      assert_equal "/checkout/success", success_uri.path
      assert_equal "{CHECKOUT_SESSION_ID}", Rack::Utils.parse_query(success_uri.query)["session_id"]
      assert_equal "/cart", cancel_uri.path
      assert_nil cancel_uri.query

      first_line_item = called_with[:line_items].first
      assert_nil first_line_item[:price]
      assert_equal 2, first_line_item[:quantity]
      assert_equal "usd", first_line_item[:price_data][:currency]
      assert_equal 3000, first_line_item[:price_data][:unit_amount]
      image_url = first_line_item[:price_data][:product_data][:images].first
      image_uri = URI.parse(image_url)

      assert_equal "http", image_uri.scheme
      assert_equal "example.com", image_uri.host
      assert_equal "/checkout/preview", image_uri.path
      assert_includes image_uri.query, "token="

      assert_equal "cs_test", JSON.parse(response.body)["sessionId"]
      assert_equal "https://checkout.test/session/cs_test", JSON.parse(response.body)["url"]
    end
  end

  test "create returns 422 when shipping currency does not match product currency" do
    user = users(:one)
    sign_in user

    product = Product.create!(stripe_product_id: "prod_test")
    cart = Cart.open_for(user)
    cart.certificate_products.create!(product: product, certificate: certificates(:one), stripe_price_id: "price_test", quantity: 1)

    ShippingRate.where(product_format: "framed").delete_all
    ShippingRate.create!(
      stripe_shipping_rate_id: "shr_framed_cad",
      stripe_shipping_rate_cache: {
        "id" => "shr_framed_cad",
        "display_name" => "USPS Ground Advantage",
        "fixed_amount" => { "amount" => 1850, "currency" => "cad" }
      },
      product_format: "framed",
      billing_basis: "per_item",
      active: true,
      default_rate: true
    )

    stripe_product = OpenStruct.new(
      id: "prod_test",
      name: "Graduation Gift",
      description: "Ceremony edition",
      metadata: { "format" => "framed" },
      default_price: "price_test_default",
      to_hash: {
        "id" => "prod_test",
        "name" => "Graduation Gift",
        "description" => "Ceremony edition",
        "metadata" => { "format" => "framed" },
        "default_price" => "price_test_default"
      }
    )
    stripe_price = OpenStruct.new(unit_amount: 3000, currency: "usd")

    stub_stripe_product_and_price_retrieve(stripe_product, stripe_price) do
      post checkout_url
    end

    assert_response :unprocessable_entity
    assert_equal "Checkout line items must all use the same currency. Found: usd, cad.", JSON.parse(response.body)["error"]
  end

  test "create prefers configured public app host over localhost request host" do
    host! "localhost:3000"

    user = users(:one)
    sign_in user

    original_url_options = Rails.application.config.action_mailer.default_url_options
    Rails.application.config.action_mailer.default_url_options = {
      host: "public-checkout.example",
      protocol: "https"
    }

    product = Product.create!(stripe_product_id: "prod_test")
    cart = Cart.open_for(user)
    cart.certificate_products.create!(product: product, certificate: certificates(:one), stripe_price_id: "price_test", quantity: 1)

    stripe_product = OpenStruct.new(
      id: "prod_test",
      name: "Graduation Gift",
      description: "Ceremony edition",
      metadata: { "format" => "framed" },
      default_price: "price_test_default",
      to_hash: {
        "id" => "prod_test",
        "name" => "Graduation Gift",
        "description" => "Ceremony edition",
        "metadata" => { "format" => "framed" },
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
        post checkout_path
      ensure
        Stripe::StripeClient.singleton_class.send(:define_method, :new, original_new)
      end

      assert_response :success
      assert_not_nil called_with

      first_line_item = called_with[:line_items].first
      image_uri = URI.parse(first_line_item[:price_data][:product_data][:images].first)
      success_uri = URI.parse(called_with[:success_url])
      cancel_uri = URI.parse(called_with[:cancel_url])

      assert_equal "https", image_uri.scheme
      assert_equal "public-checkout.example", image_uri.host
      assert_equal "https", success_uri.scheme
      assert_equal "public-checkout.example", success_uri.host
      assert_equal "/checkout/success", success_uri.path
      assert_equal "{CHECKOUT_SESSION_ID}", Rack::Utils.parse_query(success_uri.query)["session_id"]
      assert_equal "https", cancel_uri.scheme
      assert_equal "public-checkout.example", cancel_uri.host
      assert_equal "/cart", cancel_uri.path
      assert_nil cancel_uri.query
    end
  ensure
    Rails.application.config.action_mailer.default_url_options = original_url_options
    host! "www.example.com"
  end

  test "create falls back to boulder checkout image when template is invalid" do
    user = users(:one)
    sign_in user

    original_default_template = ENV["DEFAULT_CERTIFICATE_TEMPLATE"]
    ENV["DEFAULT_CERTIFICATE_TEMPLATE"] = "not_a_real_template"

    product = Product.create!(stripe_product_id: "prod_test")
    certificate = certificates(:one)
    certificate.update_column(:template, "invalid_template")

    cart = Cart.open_for(user)
    cart.certificate_products.create!(
      product: product,
      certificate: certificate,
      stripe_price_id: "price_test",
      quantity: 1
    )

    stripe_product = OpenStruct.new(
      id: "prod_test",
      name: "Graduation Gift",
      description: "Ceremony edition",
      metadata: { "format" => "framed" },
      default_price: "price_test_default",
      to_hash: {
        "id" => "prod_test",
        "name" => "Graduation Gift",
        "description" => "Ceremony edition",
        "metadata" => { "format" => "framed" },
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

      first_line_item = called_with[:line_items].first
      image_url = first_line_item[:price_data][:product_data][:images].first
      image_uri = URI.parse(image_url)
      token = Rack::Utils.parse_query(image_uri.query)["token"]
      payload = Rails.application.message_verifier(:checkout_preview).verified(token, purpose: :checkout_preview)

      assert_equal "boulder", payload[:template] || payload["template"]
    end
  ensure
    ENV["DEFAULT_CERTIFICATE_TEMPLATE"] = original_default_template
  end

  test "create uses CHECKOUT_DEFAULT_IMAGE_URL when set to absolute https url" do
    user = users(:one)
    sign_in user

    original_default_image_url = ENV["CHECKOUT_DEFAULT_IMAGE_URL"]
    ENV["CHECKOUT_DEFAULT_IMAGE_URL"] = "https://cdn.example.com/checkout/default.png"

    product = Product.create!(stripe_product_id: "prod_test")
    cart = Cart.open_for(user)
    cart.certificate_products.create!(
      product: product,
      certificate: certificates(:one),
      stripe_price_id: "price_test",
      quantity: 1
    )

    stripe_product = OpenStruct.new(
      id: "prod_test",
      name: "Graduation Gift",
      description: "Ceremony edition",
      metadata: { "format" => "framed" },
      default_price: "price_test_default",
      to_hash: {
        "id" => "prod_test",
        "name" => "Graduation Gift",
        "description" => "Ceremony edition",
        "metadata" => { "format" => "framed" },
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

      original_preview_image_url = CheckoutSessionsController.instance_method(:checkout_preview_image_url)
      CheckoutSessionsController.send(:define_method, :checkout_preview_image_url) do |checkout_session:, template:|
        nil
      end

      original_new = Stripe::StripeClient.singleton_class.instance_method(:new)
      Stripe::StripeClient.singleton_class.send(:define_method, :new) do |*args, **kwargs, &block|
        fake_client
      end

      begin
        post checkout_url
      ensure
        Stripe::StripeClient.singleton_class.send(:define_method, :new, original_new)
        CheckoutSessionsController.send(:define_method, :checkout_preview_image_url, original_preview_image_url)
      end

      assert_response :success

      first_line_item = called_with[:line_items].first
      image_url = first_line_item[:price_data][:product_data][:images].first

      assert_equal "https://cdn.example.com/checkout/default.png", image_url
    end
  ensure
    ENV["CHECKOUT_DEFAULT_IMAGE_URL"] = original_default_image_url
  end

  test "preview image returns png for an open checkout session with a valid token" do
    checkout_session = CheckoutSession.create!(status: :open, items: [ { price_id: "price_test", quantity: 1 } ], raw: {}, stripe_session_id: "cs_preview_test")
    token = CheckoutSessionsController.new.send(:checkout_preview_token, checkout_session: checkout_session, template: "boulder")
    png_data = Base64.decode64(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII="
    )

    original_preview_data = CheckoutSessionsController.instance_method(:checkout_preview_png_data)
    CheckoutSessionsController.send(:define_method, :checkout_preview_png_data) do |_template|
      png_data
    end

    get checkout_preview_url(token: token)

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal png_data, response.body
  ensure
    CheckoutSessionsController.send(:define_method, :checkout_preview_png_data, original_preview_data) if original_preview_data
  end

  test "preview image renders a real cached png for an open checkout session" do
    checkout_session = CheckoutSession.create!(status: :open, items: [ { price_id: "price_test", quantity: 1 } ], raw: {}, stripe_session_id: "cs_preview_rendered")
    token = CheckoutSessionsController.new.send(:checkout_preview_token, checkout_session: checkout_session, template: "boulder")

    get checkout_preview_url(token: token)

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_equal "\x89PNG\r\n\x1A\n".b, response.body.byteslice(0, 8)
  end

  test "preview image returns not found when the token is invalid" do
    get checkout_preview_url(token: "not-a-valid-token")

    assert_response :not_found
  end

  test "preview image returns not found when the checkout session is no longer open" do
    checkout_session = CheckoutSession.create!(status: :expired, items: [ { price_id: "price_test", quantity: 1 } ], raw: {}, stripe_session_id: "cs_preview_expired")
    token = CheckoutSessionsController.new.send(:checkout_preview_token, checkout_session: checkout_session, template: "boulder")

    get checkout_preview_url(token: token)

    assert_response :not_found
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
      metadata: { "format" => "framed" },
      default_price: "price_test_default",
      to_hash: {
        "id" => "prod_test",
        "name" => "Graduation Gift",
        "description" => "Ceremony edition",
        "metadata" => { "format" => "framed" },
        "default_price" => "price_test_default"
      }
    )
    stripe_price = OpenStruct.new(unit_amount: 3000, currency: "usd")

    stub_stripe_product_and_price_retrieve(stripe_product, stripe_price) do
      fake_session_resource = Object.new
      fake_session_resource.define_singleton_method(:create) do |_attrs|
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
        assert_enqueued_with(job: CheckoutSessionExpirationJob, args: [ previous_session.id ]) do
          post checkout_url
        end
      ensure
        Stripe::StripeClient.singleton_class.send(:define_method, :new, original_new)
      end

      assert_response :success
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
      metadata: { "format" => "framed" },
      default_price: "price_test_default",
      to_hash: {
        "id" => "prod_test",
        "name" => "Graduation Gift",
        "description" => "Ceremony edition",
        "metadata" => { "format" => "framed" },
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
      metadata: { "format" => "framed" },
      default_price: "price_test_default",
      to_hash: {
        "id" => "prod_test",
        "name" => "Graduation Gift",
        "description" => "Ceremony edition",
        "metadata" => { "format" => "framed" },
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

  test "success redirects to the order page for complete checkout session" do
    user = users(:one)
    sign_in_as(user)
    cart = Cart.create!(user: user, status: "completed")
    checkout_session = CheckoutSession.create!(
      cart: cart,
      status: :complete,
      items: [ {
        product_title: "Graditude certificate",
        product_description: "A celebratory printed certificate.",
        quantity: 1,
        unit_amount: 7200,
        currency: "usd",
        certificate_template: "boulder"
      } ],
      raw: {},
      stripe_session_id: "cs_test_123",
      shipping_total_cents: 500,
      shipping_currency: "usd"
    )

    get checkout_success_url, params: { session_id: "cs_test_123" }

    assert_redirected_to order_path(checkout_session.reload.order)

    follow_redirect!

    assert_response :success
    assert_select "h1", /Order ##{checkout_session.reload.order.number}/
    assert_match "cs_test_123", response.body
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
