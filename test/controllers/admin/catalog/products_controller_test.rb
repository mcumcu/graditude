require "test_helper"

class Admin::Catalog::ProductsControllerTest < ActionDispatch::IntegrationTest
  class FakeProvider
    def create_product!(contract:, extra_product_data: {}, extra_metadata: {})
      {
        "id" => "prod_fake",
        "name" => contract[:heading],
        "description" => contract[:description],
        "metadata" => extra_metadata
      }
    end

    def create_price!(product_id:, amount_cents:, currency:)
      {
        "id" => "price_fake",
        "unit_amount" => amount_cents,
        "currency" => currency
      }
    end

    def set_default_price!(product_id:, price_id:)
      {
        "id" => product_id,
        "default_price" => price_id,
        "name" => "Catalog Product",
        "description" => "Catalog description",
        "metadata" => {}
      }
    end

    def update_product!(product_id, contract:, extra_product_data: {}, extra_metadata: {})
      {
        "id" => product_id,
        "name" => contract[:heading],
        "description" => contract[:description],
        "metadata" => extra_metadata,
        "default_price" => "price_old"
      }
    end

    def archive_product!(product_id, fallback_cache: {})
      fallback_cache.merge("id" => product_id, "active" => false)
    end
  end

  setup do
    @admin = users(:admin)
    @user = users(:one)
    @provider = FakeProvider.new
  end

  def with_provider(provider)
    previous = Catalog.instance_variable_get(:@provider)
    Catalog.provider = provider
    yield
  ensure
    Catalog.provider = previous
  end

  test "non-admin users are redirected from catalog" do
    sign_in @user

    get admin_catalog_products_url

    assert_redirected_to root_path
  end

  test "admin can create a catalog product" do
    sign_in @admin

    params = {
      catalog_product: {
        name: "Catalog Product",
        description: "First paragraph.\n\nSecond paragraph.",
        price_amount: "45.00",
        currency: "usd"
      }
    }

    with_provider(@provider) do
      assert_difference("Product.count", 1) do
        assert_difference("Price.count", 1) do
          post admin_catalog_products_url, params: params
        end
      end
    end

    assert_redirected_to admin_catalog_products_path
    product = Product.last
    assert_equal "prod_fake", product.stripe_product_id
  end

  test "admin can update a catalog product" do
    sign_in @admin

    product = Product.create!(
      stripe_product_id: "prod_fake",
      stripe_product_cache: {
        "id" => "prod_fake",
        "name" => "Old",
        "default_price" => "price_old",
        "metadata" => { "format" => "framed" }
      }
    )
    product.prices.create!(stripe_price_id: "price_old", stripe_price_cache: { "unit_amount" => 1000, "currency" => "usd" })

    with_provider(@provider) do
      patch admin_catalog_product_url(product), params: {
        catalog_product: {
          name: "Updated Catalog Product",
          description: "Updated description",
          price_amount: "",
          currency: "usd"
        }
      }
    end

    assert_redirected_to edit_admin_catalog_product_path(product)
    assert_equal "Updated Catalog Product", product.reload.stripe_product_cache["name"]
  end

  test "admin can archive a catalog product" do
    sign_in @admin

    product = Product.create!(
      stripe_product_id: "prod_archive",
      stripe_product_cache: {
        "id" => "prod_archive",
        "name" => "Archive Me",
        "active" => true,
        "metadata" => { "format" => "framed" }
      }
    )

    with_provider(@provider) do
      delete admin_catalog_product_url(product)
    end

    assert_redirected_to admin_catalog_products_path
    assert_equal false, product.reload.stripe_product_cache["active"]
  end
end
