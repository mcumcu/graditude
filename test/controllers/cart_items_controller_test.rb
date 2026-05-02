require "test_helper"

class CartItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
    @product = Product.create!(title: "Graduation Gift", description: "Ceremony edition", price_cents: 3000, currency: "USD", details: {})
  end

  test "create adds item to cart when price map exists" do
    StripePriceMap.create!(product: @product, stripe_price_id: "price_test")

    assert_difference("CertificateProduct.count") do
      post cart_items_url, params: { product_id: @product.id, certificate_id: certificates(:one).id, quantity: 1 }
    end

    assert_redirected_to cart_path
    assert_equal "Added to cart.", flash[:notice]
  end

  test "create redirects with alert when no price map exists for product" do
    assert_no_difference("CertificateProduct.count") do
      post cart_items_url, params: { product_id: @product.id, certificate_id: certificates(:one).id }
    end

    assert_redirected_to cart_path
    assert_equal "This product is not currently available for purchase.", flash[:alert]
  end

  test "create returns unprocessable entity as JSON when no price map exists" do
    post cart_items_url,
      params: { product_id: @product.id, certificate_id: certificates(:one).id },
      as: :json

    assert_response :unprocessable_entity
    assert_equal "No active price is available for this product.", JSON.parse(response.body)["error"]
  end

  test "create redirects with error when cart item is invalid" do
    StripePriceMap.create!(product: @product, stripe_price_id: "price_test")

    assert_no_difference("CertificateProduct.count") do
      post cart_items_url, params: { product_id: @product.id, certificate_id: certificates(:one).id, quantity: -1 }
    end

    assert_redirected_to cart_path
    assert flash[:alert].present?
  end

  test "destroy removes item and redirects to cart" do
    price_map = StripePriceMap.create!(product: @product, stripe_price_id: "price_test")
    cart = Cart.open_for(@user)
    cart_item = cart.certificate_products.create!(product: @product, certificate: certificates(:one), stripe_price_map: price_map, quantity: 1)

    assert_difference("CertificateProduct.count", -1) do
      delete cart_item_url(cart_item)
    end

    assert_redirected_to cart_path
    assert_equal "Removed from cart.", flash[:notice]
  end
end
