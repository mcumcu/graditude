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

    get certificates_url
    assert_response :success
  end

  test "should get index" do
    get certificates_url
    assert_response :success
  end

  test "should get new" do
    get new_certificate_url
    assert_response :success

    assert_select "div.fixed"
    assert_select "div.absolute"
    assert_select "button[onclick=\"window.location='/certificates'\"]", text: "✖︎"
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
      metadata: { "certificate_templates" => "boulder,westtown" },
      default_price: "price_test_default",
      to_hash: {
        "id" => "prod_test",
        "name" => "Boulder Graduation Certificate",
        "description" => "A presentation-ready certificate",
        "metadata" => { "certificate_templates" => "boulder,westtown" },
        "default_price" => "price_test_default"
      }
    )
    stripe_price = OpenStruct.new(unit_amount: 2500, currency: "usd")

    stub_stripe_product_and_price_retrieve(stripe_product, stripe_price) do
      get certificate_url(@certificate)
    end

    assert_response :success
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
      metadata: { "certificate_templates" => "boulder,westtown" },
      default_price: "price_test_default",
      to_hash: {
        "id" => "prod_test",
        "name" => "Boulder Graduation Certificate",
        "description" => "A presentation-ready certificate",
        "metadata" => { "certificate_templates" => "boulder,westtown" },
        "default_price" => "price_test_default"
      }
    )
    stripe_price = OpenStruct.new(unit_amount: 2500, currency: "usd")

    stub_stripe_product_and_price_retrieve(stripe_product, stripe_price) do
      get certificate_url(@certificate)
    end

    assert_response :success
    assert_select "a[href='#{cart_path}']", text: "Already in cart"
    assert_select "form[action='#{cart_items_path}']", 0
  end

  test "should render multiple products with independent cart state" do
    product_one = Product.create!(stripe_product_id: "prod_one")
    product_two = Product.create!(stripe_product_id: "prod_two")

    product_one.update_column(:stripe_product_cache, {
      "id" => "prod_one",
      "name" => "Boulder Standard",
      "description" => "A solid certificate product",
      "metadata" => { "certificate_templates" => "boulder" },
      "default_price" => "price_one"
    })
    product_two.update_column(:stripe_product_cache, {
      "id" => "prod_two",
      "name" => "Boulder Premium",
      "description" => "A premium certificate product",
      "metadata" => { "certificate_templates" => "boulder" },
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
    assert_select "div.flex.flex-row.justify-between.items-center.gap-8.w-full", 2
    assert_match %r{Boulder Standard.*\$25\.00}m, response.body
    assert_match %r{Boulder Premium.*\$30\.00}m, response.body
    assert_select "a[href='#{cart_path}']", text: "Already in cart", minimum: 1
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
    assert_select "button[onclick=\"window.location='/certificates'\"]", text: "✖︎"
    assert_select "form[action=\"/certificates/#{@certificate.id}\"]"
  end

  test "should update certificate" do
    patch certificate_url(@certificate), params: { certificate: { graduate_name: "Updated Grad" } }
    assert_redirected_to certificate_url(@certificate)

    @certificate.reload
    assert_equal "Updated Grad", @certificate.graduate_name
  end

  test "should destroy certificate" do
    assert_difference("Certificate.count", -1) do
      delete certificate_url(@certificate)
    end

    assert_redirected_to certificates_url
  end
end
