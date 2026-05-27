require "test_helper"

class CartItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
    @product = Product.create!(stripe_product_id: "prod_test")
  end

  test "create adds item to cart when Stripe name and default_price exist" do
    stripe_product = OpenStruct.new(
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

    stub_stripe_product_retrieve(stripe_product) do
      assert_difference("CertificateProduct.count") do
        post cart_items_url, params: { product_id: @product.id, certificate_id: certificates(:one).id, quantity: 1 }
      end
    end

    assert_redirected_to cart_path
  end

  test "create redirects with alert when no Stripe product default price exists for product" do
    @product.update!(stripe_product_id: nil)

    assert_no_difference("CertificateProduct.count") do
      post cart_items_url, params: { product_id: @product.id, certificate_id: certificates(:one).id }
    end

    assert_redirected_to cart_path
    assert_equal "This product is not currently available for purchase.", flash[:alert]
  end

  test "create returns unprocessable entity as JSON when no Stripe product default price exists" do
    @product.update!(stripe_product_id: nil)

    post cart_items_url,
      params: { product_id: @product.id, certificate_id: certificates(:one).id },
      as: :json

    assert_response :unprocessable_entity
    assert_equal "No active price is available for this product.", JSON.parse(response.body)["error"]
  end

  test "create redirects with error when cart item is invalid" do
    stripe_product = OpenStruct.new(
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

    stub_stripe_product_retrieve(stripe_product) do
      assert_no_difference("CertificateProduct.count") do
        post cart_items_url, params: { product_id: @product.id, certificate_id: certificates(:one).id, quantity: -1 }
      end
    end

    assert_redirected_to cart_path
    assert flash[:alert].present?
  end

  test "create rejects purchased certificate" do
    purchased_certificate = certificates(:one)
    cart = Cart.create!(user: @user, status: "completed")

    CertificateProduct.create!(
      cart: cart,
      certificate: purchased_certificate,
      product: @product,
      stripe_price_id: "price_purchased",
      quantity: 1,
      status: "purchased"
    )

    assert_no_difference("CertificateProduct.count") do
      post cart_items_url, params: { product_id: @product.id, certificate_id: purchased_certificate.id, quantity: 1 }
    end

    assert_redirected_to certificate_url(purchased_certificate)
    assert_equal "This certificate has already been purchased.", flash[:alert]
  end

  test "destroy removes item and redirects to cart" do
    cart = Cart.open_for(@user)
    cart_item = cart.certificate_products.create!(product: @product, certificate: certificates(:one), stripe_price_id: "price_test", quantity: 1)

    assert_difference("CertificateProduct.count", -1) do
      delete cart_item_url(cart_item)
    end

    assert_redirected_to cart_path
    assert_equal "Removed from cart.", flash[:notice]
  end

  test "destroy from cart redirects to certificate show when last item is removed and user has certificates" do
    cart = Cart.open_for(@user)
    certificate = certificates(:one)
    cart_item = cart.certificate_products.create!(product: @product, certificate: certificate, stripe_price_id: "price_test", quantity: 1)

    assert_difference("CertificateProduct.count", -1) do
      delete cart_item_url(cart_item), params: { source: "cart" }
    end

    assert_redirected_to certificate_path(certificate)
    assert_equal "Removed from cart.", flash[:notice]
  end

  test "destroy from cart redirects to product when last item is removed and user has no certificates" do
    @user.certificates.destroy_all

    cart = Cart.open_for(@user)
    certificate = Certificate.create!(
      user: users(:two),
      graduate_name: "Graduate",
      honoree_name: "Honoree",
      degree: "BS",
      presented_on: Date.current.to_s,
      template: "boulder"
    )
    cart_item = cart.certificate_products.create!(product: @product, certificate: certificate, stripe_price_id: "price_test", quantity: 1)

    assert_difference("CertificateProduct.count", -1) do
      delete cart_item_url(cart_item), params: { source: "cart" }
    end

    assert_redirected_to product_path
    assert_equal "Removed from cart.", flash[:notice]
  end

  test "destroy from cart as turbo stream redirects when last item is removed" do
    cart = Cart.open_for(@user)
    certificate = certificates(:one)
    cart_item = cart.certificate_products.create!(product: @product, certificate: certificate, stripe_price_id: "price_test", quantity: 1)

    assert_difference("CertificateProduct.count", -1) do
      delete cart_item_url(cart_item), params: { source: "cart" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :see_other
    assert_equal certificate_url(certificate), response.headers["Location"]
  end
end
