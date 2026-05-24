require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  test "should get product without authentication" do
    get product_url

    assert_response :success
    assert_select "img[alt='Graditude certificate preview']"
  end

  test "uses template param when provided" do
    get product_url, params: { template: "westtown" }

    assert_response :success
    assert_select "img[alt='Graditude certificate preview'][src*='westtown']"
  end

  test "uses env default when template missing" do
    previous_default = ENV["DEFAULT_CERTIFICATE_TEMPLATE"]
    ENV["DEFAULT_CERTIFICATE_TEMPLATE"] = "penn"

    get product_url

    assert_response :success
    assert_select "img[alt='Graditude certificate preview'][src*='penn']"
  ensure
    if previous_default.nil?
      ENV.delete("DEFAULT_CERTIFICATE_TEMPLATE")
    else
      ENV["DEFAULT_CERTIFICATE_TEMPLATE"] = previous_default
    end
  end

  test "falls back to boulder when env missing" do
    previous_default = ENV["DEFAULT_CERTIFICATE_TEMPLATE"]
    ENV.delete("DEFAULT_CERTIFICATE_TEMPLATE")

    get product_url

    assert_response :success
    assert_select "img[alt='Graditude certificate preview'][src*='boulder']"
  ensure
    if previous_default.nil?
      ENV.delete("DEFAULT_CERTIFICATE_TEMPLATE")
    else
      ENV["DEFAULT_CERTIFICATE_TEMPLATE"] = previous_default
    end
  end
end
