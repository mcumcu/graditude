require "test_helper"
require "catalog/broadcasts"

class Catalog::BroadcastsTest < ActionDispatch::IntegrationTest
  setup do
    @product = Product.create!(name: "Test Product", sku: "SKU-001")
  end

  teardown do
    @product&.destroy
  end

  test "product_created should broadcast Turbo Stream prepend" do
    broadcasts = Catalog::Broadcasts.new
    broadcasts.product_created(@product)
    
    assert_equal "product.created", broadcasts.action
    assert_equal "products", broadcasts.target
    assert_equal @product.id.to_s, broadcasts.id
    assert_equal "prepend", broadcasts.method
    assert_equal @product.name, broadcasts.content[:name]
    assert_equal @product.sku, broadcasts.content[:sku]
  end

  test "product_updated should broadcast Turbo Stream replace" do
    product = Product.create!(name: "Original Product", sku: "SKU-001")
    broadcasts = Catalog::Broadcasts.new
    broadcasts.product_updated(product)
    
    assert_equal "product.updated", broadcasts.action
    assert_equal "products", broadcasts.target
    assert_equal product.id.to_s, broadcasts.id
    assert_equal "replace", broadcasts.method
    assert_equal product.name, broadcasts.content[:name]
    assert_equal product.sku, broadcasts.content[:sku]
    product.destroy
  end

  test "product_removed should broadcast Turbo Stream remove" do
    product = Product.create!(name: "Test Product", sku: "SKU-001")
    broadcasts = Catalog::Broadcasts.new
    broadcasts.product_removed(product)
    
    assert_equal "product.removed", broadcasts.action
    assert_equal "products", broadcasts.target
    assert_equal product.id.to_s, broadcasts.id
    assert_equal "remove", broadcasts.method
    product.destroy
  end

  test "row_dom_id should generate correct DOM ID" do
    product = Product.create!(name: "Test Product", sku: "SKU-001")
    broadcasts = Catalog::Broadcasts.new
    dom_id = broadcasts.row_dom_id(product)
    
    assert_equal "product_#{product.id}", dom_id
    product.destroy
  end

  test "product_created with custom channel should use custom channel" do
    custom_channel = "custom_channel"
    broadcasts = Catalog::Broadcasts.new(channel: custom_channel)
    broadcasts.product_created(@product)
    
    assert_equal custom_channel, broadcasts.channel
  end

  test "product_updated with custom channel should use custom channel" do
    product = Product.create!(name: "Test Product", sku: "SKU-001")
    custom_channel = "custom_channel"
    broadcasts = Catalog::Broadcasts.new(channel: custom_channel)
    broadcasts.product_updated(product)
    
    assert_equal custom_channel, broadcasts.channel
    product.destroy
  end

  test "product_removed with custom channel should use custom channel" do
    product = Product.create!(name: "Test Product", sku: "SKU-001")
    custom_channel = "custom_channel"
    broadcasts = Catalog::Broadcasts.new(channel: custom_channel)
    broadcasts.product_removed(product)
    
    assert_equal custom_channel, broadcasts.channel
    product.destroy
  end
end