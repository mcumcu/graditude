require "test_helper"
require "ostruct"

class CertificatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @certificate = certificates(:one)
    sign_in
  end

  test "sign_in helper creates a Session record and authenticates protected routes" do
    sign_out

    assert_difference("Session.count") do
      sign_in users(:one)
    end

    assert_not_nil cookies["session_id"], "expected signed session cookie to be present after sign_in"

    create_additional_certificate_for(users(:one), honoree_name: "Honoree Extra")
    get certificates_url
    assert_response :success
  end

  test "should get index" do
    create_additional_certificate_for(users(:one), honoree_name: "Honoree Extra")
    get certificates_url
    assert_response :success
  end

  test "index only shows current user's certificates" do
    create_additional_certificate_for(users(:one), honoree_name: "Honoree Extra")
    get certificates_url
    assert_response :success

    assert_select "h3", text: "Honoree One"
    assert_select "h3", text: "Honoree Extra"
    assert_select "h3", text: "Honoree Two", count: 0
  end

  test "index shows purchased badge for purchased certificate" do
    user = users(:one)
    cart = Cart.create!(user: user, status: "completed")
    product = Product.create!(stripe_product_id: "prod_badge")

    CertificateProduct.create!(
      cart: cart,
      certificate: @certificate,
      product: product,
      stripe_price_id: "price_badge",
      quantity: 1,
      status: "purchased"
    )

    get certificates_url

    assert_response :success
    assert_select "span", text: "Purchased", count: 1
  end

  test "index shows purchased list and create new CTA when no purchasable certificates exist" do
    user = users(:one)
    cart = Cart.create!(user: user, status: "completed")
    product = Product.create!(stripe_product_id: "prod_purchased_only")

    CertificateProduct.create!(
      cart: cart,
      certificate: @certificate,
      product: product,
      stripe_price_id: "price_purchased_only",
      quantity: 1,
      status: "purchased"
    )

    get certificates_url

    assert_response :success
    assert_select "h2", text: "Purchased certificates", count: 1
    assert_select "a[href='#{new_certificate_path(close_path: certificates_path)}']", text: "Create a new certificate", count: 1
  end

  test "index shows purchasable and purchased certificates together" do
    user = users(:one)
    cart = Cart.create!(user: user, status: "completed")
    product = Product.create!(stripe_product_id: "prod_mixed")

    CertificateProduct.create!(
      cart: cart,
      certificate: @certificate,
      product: product,
      stripe_price_id: "price_mixed",
      quantity: 1,
      status: "purchased"
    )

    create_additional_certificate_for(user, honoree_name: "Honoree Extra")

    get certificates_url

    assert_response :success
    assert_select "h2", text: "Purchased certificates", count: 1
    assert_select "h3", text: "Honoree One"
    assert_select "h3", text: "Honoree Extra"
  end

  test "should get new" do
    get new_certificate_url
    assert_response :success

    assert_select "div.fixed"
    assert_select "div.absolute"
    assert_select "a[aria-label='Close dialog'][href='#{certificates_path}']", text: "✖︎"
    assert_select "form[action=\"/certificates\"]"
  end

  test "should create certificate" do
    assert_difference("Certificate.count") do
      post certificates_url, params: {
        certificate: {
          graduate_name: "New Grad",
          honoree_name: "Honoree Recipient",
          degree: "Bachelor of Science",
          presented_on: "2026-05-15"
        }
      }
    end

    new_certificate = Certificate.order(created_at: :desc).first
    assert_redirected_to certificate_url(new_certificate)
    assert_equal @certificate.user_id, new_certificate.user_id
  end

  test "should create certificate with preferred format" do
    assert_difference("Certificate.count") do
      post certificates_url, params: {
        preferred_format: "pdf",
        certificate: {
          graduate_name: "Preferred Grad",
          honoree_name: "Preferred Honoree",
          degree: "Bachelor of Arts",
          presented_on: "2026-05-15"
        }
      }
    end

    new_certificate = Certificate.order(created_at: :desc).first
    assert_redirected_to certificate_url(new_certificate, preferred_format: "pdf")
  end

  test "should return bad request when certificate params are missing" do
    assert_no_difference("Certificate.count") do
      post certificates_url, params: {}
    end

    assert_response :bad_request
  end

  test "should show certificate" do
    stripe_product = OpenStruct.new(
      id: "prod_test",
      name: "Boulder Graduation Certificate",
      description: "A presentation-ready certificate",
      metadata: { "certificate_templates" => "boulder,westtown", "format" => "framed" },
      default_price: "price_test_default",
      to_hash: {
        "id" => "prod_test",
        "name" => "Boulder Graduation Certificate",
        "description" => "A presentation-ready certificate",
        "metadata" => { "certificate_templates" => "boulder,westtown", "format" => "framed" },
        "default_price" => "price_test_default"
      }
    )
    stripe_price = OpenStruct.new(unit_amount: 2500, currency: "usd")

    stub_stripe_product_and_price_retrieve(stripe_product, stripe_price) do
      get certificate_url(@certificate)
    end

    assert_response :success
    assert_select "[data-preview-src-value='#{preview_certificate_path(@certificate)}']", count: 1
    assert_select "img[data-controller='preview']", 0
    assert_no_match %r{#{Regexp.escape(preview_certificate_path(@certificate, format: :png))}}, response.body
  end

  test "should hide purchase options when certificate is purchased" do
    user = users(:one)
    cart = Cart.create!(user: user, status: "completed")
    product = Product.create!(stripe_product_id: "prod_purchased")

    CertificateProduct.create!(
      cart: cart,
      certificate: @certificate,
      product: product,
      stripe_price_id: "price_purchased",
      quantity: 1,
      status: "purchased"
    )

    stripe_product = OpenStruct.new(
      id: "prod_purchased",
      name: "Boulder Graduation Certificate",
      description: "A presentation-ready certificate",
      metadata: { "certificate_templates" => "boulder,westtown", "format" => "framed" },
      default_price: "price_test_default",
      to_hash: {
        "id" => "prod_purchased",
        "name" => "Boulder Graduation Certificate",
        "description" => "A presentation-ready certificate",
        "metadata" => { "certificate_templates" => "boulder,westtown", "format" => "framed" },
        "default_price" => "price_test_default"
      }
    )
    stripe_price = OpenStruct.new(unit_amount: 2500, currency: "usd")

    stub_stripe_product_and_price_retrieve(stripe_product, stripe_price) do
      get certificate_url(@certificate)
    end

    assert_response :success
    assert_select "input[name='product_id']", 0
    assert_select "div[data-purchased-message]", text: "This certificate has already been purchased and is no longer available to add to cart.", count: 1
  end

  test "should not show delete button when certificate is in cart" do
    user = users(:one)
    cart = Cart.open_for(user)
    product = Product.create!(stripe_product_id: "prod_test")

    CertificateProduct.create!(
      cart: cart,
      certificate: @certificate,
      product: product,
      stripe_price_id: "price_test_cart",
      quantity: 1,
      status: "pending"
    )

    stripe_product = OpenStruct.new(
      id: "prod_test",
      name: "Boulder Graduation Certificate",
      description: "A presentation-ready certificate",
      metadata: { "certificate_templates" => "boulder,westtown", "format" => "framed" },
      default_price: "price_test_default",
      to_hash: {
        "id" => "prod_test",
        "name" => "Boulder Graduation Certificate",
        "description" => "A presentation-ready certificate",
        "metadata" => { "certificate_templates" => "boulder,westtown", "format" => "framed" },
        "default_price" => "price_test_default"
      }
    )
    stripe_price = OpenStruct.new(unit_amount: 2500, currency: "usd")

    stub_stripe_product_and_price_retrieve(stripe_product, stripe_price) do
      get certificate_url(@certificate)
    end

    assert_response :success
    assert_select "button[disabled]", text: "Delete", count: 1
  end

  test "should not destroy certificate when it is in cart" do
    cart = Cart.open_for(users(:one))
    product = Product.create!(stripe_product_id: "prod_delete_test")

    CertificateProduct.create!(
      cart: cart,
      certificate: @certificate,
      product: product,
      stripe_price_id: "price_delete_test",
      quantity: 1,
      status: "pending"
    )

    assert_no_difference("Certificate.count") do
      delete certificate_url(@certificate)
    end

    assert_redirected_to certificate_url(@certificate)
    assert_equal "Remove this certificate from your cart before deleting it.", flash[:alert]
  end

  test "should show already in cart link when certificate is already in cart" do
    product = Product.create!(stripe_product_id: "prod_test")
    cart = Cart.open_for(users(:one))

    CertificateProduct.create!(
      cart: cart,
      certificate: @certificate,
      product: product,
      stripe_price_id: "price_test_already_in_cart",
      quantity: 1,
      status: "pending"
    )

    stripe_product = OpenStruct.new(
      id: "prod_test",
      name: "Boulder Graduation Certificate",
      description: "A presentation-ready certificate",
      metadata: { "certificate_templates" => "boulder,westtown", "format" => "framed" },
      default_price: "price_test_default",
      to_hash: {
        "id" => "prod_test",
        "name" => "Boulder Graduation Certificate",
        "description" => "A presentation-ready certificate",
        "metadata" => { "certificate_templates" => "boulder,westtown", "format" => "framed" },
        "default_price" => "price_test_default"
      }
    )
    stripe_price = OpenStruct.new(unit_amount: 2500, currency: "usd")

    stub_stripe_product_and_price_retrieve(stripe_product, stripe_price) do
      get certificate_url(@certificate)
    end

    assert_response :success
    assert_select "a[title='Remove from cart']", count: 1
    assert_select "input[name='product_id']", 0
  end

  test "should render multiple products with independent cart state" do
    product_one = Product.create!(stripe_product_id: "prod_one")
    product_two = Product.create!(stripe_product_id: "prod_two")

    product_one.update_column(:stripe_product_cache, {
      "id" => "prod_one",
      "name" => "Boulder Standard",
      "description" => "A solid certificate product",
      "metadata" => { "certificate_templates" => "boulder", "format" => "framed" },
      "default_price" => "price_one"
    })
    product_two.update_column(:stripe_product_cache, {
      "id" => "prod_two",
      "name" => "Boulder Premium",
      "description" => "A premium certificate product",
      "metadata" => { "certificate_templates" => "boulder", "format" => "framed" },
      "default_price" => "price_two"
    })

    cart = Cart.open_for(users(:one))
    CertificateProduct.create!(
      cart: cart,
      certificate: @certificate,
      product: product_one,
      stripe_price_id: "price_one",
      quantity: 1,
      status: "pending"
    )

    original_price_retrieve = Stripe::Price.method(:retrieve)
    Stripe::Price.define_singleton_method(:retrieve) do |price_id|
      case price_id
      when "price_one"
        OpenStruct.new(unit_amount: 2500, currency: "usd")
      when "price_two"
        OpenStruct.new(unit_amount: 3000, currency: "usd")
      else
        raise "Unexpected price_id: #{price_id}"
      end
    end

    get certificate_url(@certificate)

    assert_response :success
    assert_select "[data-product-card]", 2
    assert_select "a[title='Remove from cart']", count: 1
    assert_select "input[name='product_id'][value='#{product_two.id}']", 1
    assert_select "input[name='product_id'][value='#{product_one.id}']", 0
  ensure
    Stripe::Price.define_singleton_method(:retrieve, original_price_retrieve)
  end

  test "should get edit" do
    get edit_certificate_url(@certificate)
    assert_response :success

    assert_select "div.fixed"
    assert_select "div.absolute"
    assert_select "a[aria-label='Close dialog'][href='#{certificate_path(@certificate)}']", text: "✖︎"
    assert_select "form[action=\"/certificates/#{@certificate.id}\"]"
  end

  test "should not allow edit when certificate is purchased" do
    user = users(:one)
    cart = Cart.create!(user: user, status: "completed")
    product = Product.create!(stripe_product_id: "prod_edit_blocked")

    CertificateProduct.create!(
      cart: cart,
      certificate: @certificate,
      product: product,
      stripe_price_id: "price_edit_blocked",
      quantity: 1,
      status: "purchased"
    )

    get edit_certificate_url(@certificate)

    assert_redirected_to certificate_url(@certificate)
    assert_equal "Purchased certificates cannot be edited.", flash[:alert]
  end

  test "should update certificate" do
    patch certificate_url(@certificate), params: { certificate: { graduate_name: "Updated Grad" } }
    assert_redirected_to certificate_url(@certificate)

    @certificate.reload
    assert_equal "Updated Grad", @certificate.graduate_name
  end

  test "should not update certificate when it is purchased" do
    user = users(:one)
    cart = Cart.create!(user: user, status: "completed")
    product = Product.create!(stripe_product_id: "prod_update_blocked")

    CertificateProduct.create!(
      cart: cart,
      certificate: @certificate,
      product: product,
      stripe_price_id: "price_update_blocked",
      quantity: 1,
      status: "purchased"
    )

    patch certificate_url(@certificate), params: { certificate: { graduate_name: "Blocked Update" } }

    assert_redirected_to certificate_url(@certificate)
    assert_equal "Purchased certificates cannot be edited.", flash[:alert]

    @certificate.reload
    assert_not_equal "Blocked Update", @certificate.graduate_name
  end

  test "should not set notice when certificate update has no changes" do
    patch certificate_url(@certificate), params: { certificate: { graduate_name: @certificate.graduate_name } }

    assert_redirected_to certificate_url(@certificate)
    assert_nil flash[:notice]
  end

  test "should return inline preview data url" do
    get preview_certificate_url(@certificate)

    assert_response :success
    assert_match %r{\Aurl\('data:image/png;base64,[A-Za-z0-9+/]+=*'\)\z}, @response.body
  end

  test "should not expose preview as raw png when png format is requested" do
    get preview_certificate_url(@certificate, format: :png)

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_match %r{\Aurl\('data:image/png;base64,[A-Za-z0-9+/]+=*'\)\z}, @response.body
  end

  test "should return not found when preview is unavailable" do
    CertificatesController.class_eval do
      alias_method :original_rerender_png_data_url_for_test, :rerender_png_data_url

      def rerender_png_data_url
        nil
      end
    end

    get preview_certificate_url(@certificate)

    assert_response :not_found
  ensure
    CertificatesController.class_eval do
      if method_defined?(:original_rerender_png_data_url_for_test)
        alias_method :rerender_png_data_url, :original_rerender_png_data_url_for_test
        remove_method :original_rerender_png_data_url_for_test
      end
    end
  end

  test "should return json error when certificate is in cart" do
    cart = Cart.open_for(users(:one))
    product = Product.create!(stripe_product_id: "prod_delete_json")

    CertificateProduct.create!(
      cart: cart,
      certificate: @certificate,
      product: product,
      stripe_price_id: "price_delete_json",
      quantity: 1,
      status: "pending"
    )

    delete certificate_url(@certificate, format: :json)

    assert_response :unprocessable_entity
    payload = JSON.parse(response.body)
    assert_equal "Remove this certificate from your cart before deleting it.", payload["error"]
  end

  test "should destroy certificate" do
    assert_difference("Certificate.count", -1) do
      delete certificate_url(@certificate)
    end

    assert_redirected_to certificates_url
  end

  test "should redirect to remaining certificate show when one certificate remains" do
    remaining_certificate = create_additional_certificate_for(users(:one), honoree_name: "Honoree Remaining")

    assert_difference("Certificate.count", -1) do
      delete certificate_url(@certificate)
    end

    assert_redirected_to certificate_url(remaining_certificate)
  end

  test "should redirect to index when multiple certificates remain" do
    create_additional_certificate_for(users(:one), honoree_name: "Honoree Extra One")
    create_additional_certificate_for(users(:one), honoree_name: "Honoree Extra Two")

    assert_difference("Certificate.count", -1) do
      delete certificate_url(@certificate)
    end

    assert_redirected_to certificates_url
  end

  test "should destroy certificate with json response" do
    delete certificate_url(@certificate, format: :json)

    assert_response :no_content
    assert_equal "", response.body
  end

  private

  def create_additional_certificate_for(user, honoree_name: "Honoree Extra")
    Certificate.create!(
      user: user,
      graduate_name: "Extra Graduate",
      honoree_name: honoree_name,
      degree: "Bachelor of Arts",
      presented_on: "2026-05-15"
    )
  end
end
