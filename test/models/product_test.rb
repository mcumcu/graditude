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
end
