require "test_helper"
require "ostruct"

class ProductTest < ActiveSupport::TestCase
  test "stripe_product delegates to Stripe and exposes metadata templates" do
    stripe_product = OpenStruct.new(
      name: "Stripe Product Name",
      description: "Stripe product description",
      metadata: { "certificate_templates" => "boulder,westtown" },
      default_price: "price_test_default"
    )

    original_product_retrieve = Stripe::Product.method(:retrieve)
    original_price_retrieve = Stripe::Price.method(:retrieve)
    original_api_key = Stripe.api_key

    Stripe.api_key = "sk_test_stubbed"
    Stripe::Product.define_singleton_method(:retrieve) do |_id|
      OpenStruct.new(
        name: "Stripe Product Name",
        description: "Stripe product description",
        metadata: { "certificate_templates" => "boulder,westtown" },
        default_price: "price_test_default",
        to_hash: {
          "id" => "prod_test_delegates",
          "name" => "Stripe Product Name",
          "description" => "Stripe product description",
          "metadata" => { "certificate_templates" => "boulder,westtown" },
          "default_price" => "price_test_default"
        }
      )
    end
    Stripe::Price.define_singleton_method(:retrieve) do |price_id|
      OpenStruct.new(id: price_id, unit_amount: 3500, currency: "usd")
    end

    product = Product.create!(stripe_product_id: "prod_test_delegates")
    Rails.cache.delete(product.send(:stripe_product_cache_key))

    begin
      assert_equal "Stripe Product Name", product.title
      assert_equal "Stripe product description", product.description
      assert_equal %w[boulder westtown], product.certificate_template_names
      assert_equal "price_test_default", product.stripe_price_id
      assert_equal 3500, product.stripe_price_amount_cents
      assert_equal "usd", product.stripe_price_currency
    ensure
      Stripe.api_key = original_api_key
      if original_product_retrieve
        Stripe::Product.define_singleton_method(:retrieve, original_product_retrieve.to_proc)
      end
      if original_price_retrieve
        Stripe::Price.define_singleton_method(:retrieve, original_price_retrieve.to_proc)
      end
    end
  end

  test "default_price creates a cached Price record for the product default price" do
    stripe_product = OpenStruct.new(
      id: "prod_test_default",
      name: "Stripe Product Name",
      description: "Stripe product description",
      metadata: { "certificate_templates" => "boulder" },
      default_price: "price_test_default",
      to_hash: {
        "id" => "prod_test_default",
        "name" => "Stripe Product Name",
        "description" => "Stripe product description",
        "metadata" => { "certificate_templates" => "boulder" },
        "default_price" => "price_test_default"
      }
    )

    original_retrieve = Stripe::Product.method(:retrieve)
    Stripe::Product.define_singleton_method(:retrieve) { |_id| stripe_product }
    original_price_retrieve = Stripe::Price.method(:retrieve)
    Stripe::Price.define_singleton_method(:retrieve) do |price_id|
      OpenStruct.new(id: price_id, unit_amount: 2700, currency: "usd", to_hash: { "id" => price_id, "unit_amount" => 2700, "currency" => "usd" })
    end

    product = Product.create!(stripe_product_id: "prod_test_default")
    Rails.cache.delete(product.send(:stripe_product_cache_key))

    price_record = product.default_price

    assert_equal product, price_record.product
    assert_equal "price_test_default", price_record.stripe_price_id
    assert_equal 2700, product.stripe_price_amount_cents
  ensure
    if original_retrieve
      Stripe::Product.define_singleton_method(:retrieve, original_retrieve.to_proc)
    end
    if original_price_retrieve
      Stripe::Price.define_singleton_method(:retrieve, original_price_retrieve.to_proc)
    end
  end

  test "stripe_product_data caches stripe product payload in stripe_product_cache and Rails cache" do
    product = Product.create!(stripe_product_id: "prod_test_cache")
    stripe_product = OpenStruct.new(
      id: "prod_test_cache",
      name: "Stripe Product Name",
      description: "Stripe product description",
      metadata: { "certificate_templates" => "boulder,westtown" },
      default_price: "price_test_default",
      to_hash: {
        "id" => "prod_test",
        "name" => "Stripe Product Name",
        "description" => "Stripe product description",
        "metadata" => { "certificate_templates" => "boulder,westtown" },
        "default_price" => "price_test_default"
      }
    )

    original_retrieve = Stripe::Product.method(:retrieve)
    Stripe::Product.define_singleton_method(:retrieve) { |id| stripe_product }

    Rails.cache.delete(product.send(:stripe_product_cache_key))

    product_data = product.stripe_product_data

    assert_equal "Stripe Product Name", product_data["name"]
    assert_equal "Stripe product description", product.stripe_description
    assert_equal %w[boulder westtown], product.certificate_template_names
    assert_equal "Stripe Product Name", product.reload.stripe_product_cache["name"]
  ensure
    if defined?(original_retrieve) && original_retrieve
      Stripe::Product.define_singleton_method(:retrieve, original_retrieve.to_proc)
    end
  end

  test "for_certificate_template filters by template and returns products sorted by price descending" do
    product_a = Product.create!(
      stripe_product_id: "prod_a",
      stripe_product_cache: {
        "id" => "prod_a",
        "name" => "Zed Certificate",
        "description" => "Zed description",
        "metadata" => { "certificate_templates" => "boulder" },
        "default_price" => "price_a"
      }
    )

    product_b = Product.create!(
      stripe_product_id: "prod_b",
      stripe_product_cache: {
        "id" => "prod_b",
        "name" => "Alpha Certificate",
        "description" => "Alpha description",
        "metadata" => { "certificate_templates" => "boulder,westtown" },
        "default_price" => "price_b"
      }
    )

    Product.create!(
      stripe_product_id: "prod_c",
      stripe_product_cache: {
        "id" => "prod_c",
        "name" => "Westtown Certificate",
        "description" => "Westtown description",
        "metadata" => { "certificate_templates" => "westtown" },
        "default_price" => "price_c"
      }
    )

    original_price_retrieve = Stripe::Price.method(:retrieve)
    Stripe::Price.define_singleton_method(:retrieve) do |price_id|
      case price_id
      when "price_a"
        OpenStruct.new(unit_amount: 5000)
      when "price_b"
        OpenStruct.new(unit_amount: 3000)
      when "price_c"
        OpenStruct.new(unit_amount: 1000)
      else
        raise "Unexpected price_id: #{price_id}"
      end
    end

    results = Product.for_certificate_template("boulder")

    assert_equal [ product_a, product_b ], results
  ensure
    Stripe::Price.define_singleton_method(:retrieve, original_price_retrieve.to_proc)
  end

  test "clear_stripe_product_cache! removes both Rails cache and persisted stripe_product_cache" do
    product = Product.create!(stripe_product_id: "prod_test_clear", stripe_product_cache: { "id" => "prod_test_clear", "name" => "Old Product" })

    assert_equal({ "id" => "prod_test_clear", "name" => "Old Product" }, product.reload.stripe_product_cache)

    deleted = false
    original_delete = Rails.cache.method(:delete)
    Rails.cache.define_singleton_method(:delete) do |key|
      deleted = true
    end

    begin
      product.clear_stripe_product_cache!
    ensure
      Rails.cache.define_singleton_method(:delete, original_delete.to_proc)
    end

    assert_equal true, deleted
    assert_equal({}, product.reload.stripe_product_cache)
  end

  test "clear_stripe_product_cache! also clears the default price cache when the product default price changes" do
    product = Product.create!(
      stripe_product_id: "prod_test_price_clear_default",
      stripe_product_cache: {
        "id" => "prod_test_price_clear_default",
        "name" => "Product With Price",
        "metadata" => { "certificate_templates" => "boulder" },
        "default_price" => "price_old"
      }
    )

    price = product.prices.create!(stripe_price_id: "price_old", stripe_price_cache: { "unit_amount" => 2500, "currency" => "usd" })
    Rails.cache.write(price.send(:stripe_price_cache_key), price.stripe_price_cache)

    product.clear_stripe_product_cache!

    assert_nil Rails.cache.read(price.send(:stripe_price_cache_key))
    assert_equal({}, price.reload.stripe_price_cache)
  end

  test "changing stripe_product_id clears old cache and persisted stripe_product_cache" do
    product = Product.create!(stripe_product_id: "old_id", stripe_product_cache: { "id" => "old_id", "name" => "Old Product" })
    assert_equal({ "id" => "old_id", "name" => "Old Product" }, product.reload.stripe_product_cache)

    deleted_key = nil
    original_delete = Rails.cache.method(:delete)
    Rails.cache.define_singleton_method(:delete) do |key|
      deleted_key = key
    end

    begin
      product.update!(stripe_product_id: "new_id")
    ensure
      Rails.cache.define_singleton_method(:delete, original_delete.to_proc)
    end

    assert_equal({}, product.reload.stripe_product_cache)
    assert_equal "stripe_product:old_id", deleted_key
  end
end
