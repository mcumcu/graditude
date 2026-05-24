require "test_helper"

class RoutesTest < ActionDispatch::IntegrationTest
  test "routes product page" do
    assert_routing "/product", controller: "products", action: "show"
  end

  test "routes certificate preview" do
    assert_routing "/certificates/1/preview", controller: "certificates", action: "preview", id: "1"
  end

  test "routes root" do
    assert_routing "/", controller: "landing", action: "index"
  end
end
