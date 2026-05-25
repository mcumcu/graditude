require "test_helper"

class AdminCatalogProductFormTest < ActiveSupport::TestCase
  test "from_product formats marketing features and price" do
    product = Product.create!(
      stripe_product_id: "prod_form",
      stripe_product_cache: {
        "id" => "prod_form",
        "name" => "Certificate",
        "description" => "Description",
        "metadata" => { "format" => "framed" },
        "marketing_features" => [
          { "name" => "Premium print", "description" => "Crisp" }
        ],
        "default_price" => "price_form"
      }
    )
    product.prices.create!(
      stripe_price_id: "price_form",
      stripe_price_cache: { "unit_amount" => 4200, "currency" => "usd" }
    )

    form = Admin::CatalogProductForm.from_product(product)

    assert_equal "Premium print | Crisp", form.marketing_features_text
    assert_equal "42.00", form.price_amount
  end
end
