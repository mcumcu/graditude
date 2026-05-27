require "test_helper"

class CertificatesHelperTest < ActionView::TestCase
  include CertificatesHelper

  def teardown
    Current.reset
  end

  test "formatted_stripe_price formats price when present" do
    product = Struct.new(:catalog_data).new({ default_price_amount_cents: 2500, default_price_currency: "usd" })

    assert_equal "$25.00", formatted_stripe_price(product)
  end

  test "formatted_stripe_price returns nil when price missing" do
    product = Struct.new(:catalog_data).new({ default_price_amount_cents: nil, default_price_currency: nil })

    assert_nil formatted_stripe_price(product)
  end

  test "currency_symbol maps known and unknown currencies" do
    assert_equal "$", currency_symbol("USD")
    assert_equal "€", currency_symbol("eur")
    assert_equal "£", currency_symbol("gbp")
    assert_equal "CAD ", currency_symbol("cad")
  end

  test "price_label_for falls back when no priced products" do
    product = Struct.new(:catalog_data).new({ default_price_amount_cents: nil })

    assert_equal "Pricing available at checkout", price_label_for([ product ])
  end

  test "price_label_for returns single price when uniform" do
    product = Struct.new(:catalog_data).new({ default_price_amount_cents: 2500, default_price_currency: "usd" })

    assert_equal "$25.00", price_label_for([ product ])
  end

  test "price_label_for returns from price when multiple" do
    product_low = Struct.new(:catalog_data).new({ default_price_amount_cents: 2500, default_price_currency: "usd" })
    product_high = Struct.new(:catalog_data).new({ default_price_amount_cents: 3000, default_price_currency: "usd" })

    assert_equal "From $25.00", price_label_for([ product_high, product_low ])
  end

  test "product_variant_format respects metadata" do
    product = Struct.new(:variant_format).new("framed")

    assert_equal "framed", product_variant_format(product)
    assert_equal "Framed", product_variant_label(product)
  end

  test "product_variant_format uses title when metadata missing" do
    product = Struct.new(:variant_format).new("unframed")

    assert_equal "unframed", product_variant_format(product)
    assert_equal "Unframed", product_variant_label(product)
  end

  test "product_variant_label falls back when unknown" do
    product = Struct.new(:variant_format).new(nil)

    assert_equal "Certificate", product_variant_label(product)
  end

  test "products_for_template filters and sorts by title" do
    product_alpha = Product.create!(
      stripe_product_id: "prod_alpha",
      stripe_product_cache: {
        "name" => "Alpha",
        "metadata" => { "certificate_templates" => "boulder", "format" => "framed" }
      }
    )
    product_beta = Product.create!(
      stripe_product_id: "prod_beta",
      stripe_product_cache: {
        "name" => "beta",
        "metadata" => { "certificate_templates" => "boulder", "format" => "framed" }
      }
    )
    Product.create!(
      stripe_product_id: "prod_other",
      stripe_product_cache: {
        "name" => "Gamma",
        "metadata" => { "certificate_templates" => "westtown", "format" => "framed" }
      }
    )

    results = products_for_template("boulder")

    assert_equal [ product_alpha, product_beta ], results
  end

  test "products_for_template uses default template when blank" do
    previous_default = ENV["DEFAULT_CERTIFICATE_TEMPLATE"]
    ENV["DEFAULT_CERTIFICATE_TEMPLATE"] = "boulder"

    product_default = Product.create!(
      stripe_product_id: "prod_default",
      stripe_product_cache: {
        "name" => "Default",
        "metadata" => { "certificate_templates" => "boulder", "format" => "framed" }
      }
    )

    results = products_for_template(nil)

    assert_equal [ product_default ], results
  ensure
    if previous_default.nil?
      ENV.delete("DEFAULT_CERTIFICATE_TEMPLATE")
    else
      ENV["DEFAULT_CERTIFICATE_TEMPLATE"] = previous_default
    end
  end

  test "certificate_in_cart? returns false without a current user" do
    Current.reset

    assert_not certificate_in_cart?(certificates(:one))
  end

  test "certificate_in_cart? and product_in_cart? reflect cart contents" do
    user = users(:one)
    Current.session = user.sessions.create!(user_agent: "Helper Test", ip_address: "127.0.0.1")

    cart = Cart.open_for(user)
    product = Product.create!(stripe_product_id: "prod_cart")
    certificate = certificates(:one)

    CertificateProduct.create!(
      cart: cart,
      certificate: certificate,
      product: product,
      stripe_price_id: "price_cart",
      quantity: 1,
      status: "pending"
    )

    assert certificate_in_cart?(certificate)
    assert product_in_cart?(product.id, certificate: certificate)
    assert_not product_in_cart?(product.id, certificate: certificates(:two))
  end

  test "product_in_cart? returns false without a current user" do
    Current.reset

    assert_not product_in_cart?(123, certificate: certificates(:one))
  end
end
