require "test_helper"
require "ostruct"

class CheckoutSessionsControllerTest < ActionDispatch::IntegrationTest
  test "new renders successfully with price_id" do
    get new_checkout_url, params: { price_id: "price_1S7JZoBKCB1NBOVa2U4OXmFy" }

    assert_response :success
    assert_select "h1", "Graditude Certificate"
    assert_select "button", "Start checkout"
  end

  test "new renders certificate preview from certificate_id" do
    certificate = certificates(:one)
    certificate.update!(template: "westtown", major: "Computer Science")

    get new_checkout_url, params: { certificate_id: certificate.id }

    assert_response :success
    assert_select "h1", "Westtown Graduation Certificate"
    assert_select "img[src*='preview']"
  end

  test "create uses template price id when price_id is omitted" do
    certificate = certificates(:one)
    certificate.update!(template: "westtown", major: "Computer Science")

    called_with = nil
    original_create = Stripe::Checkout::Session.method(:create)

    Stripe::Checkout::Session.define_singleton_method(:create) do |attrs|
      called_with = attrs
      OpenStruct.new(id: "cs_test")
    end

    post checkout_url, params: { certificate_id: certificate.id }

    assert_response :success
    assert_equal "price_1S7JZoBKCB1NBOVa2U4OXmFz", called_with[:line_items].first[:price]
  ensure
    Stripe::Checkout::Session.define_singleton_method(:create, original_create) if defined?(original_create) && original_create
  end

  test "create returns checkout session id" do
    original_create = Stripe::Checkout::Session.method(:create)

    Stripe::Checkout::Session.define_singleton_method(:create) do |_attrs|
      OpenStruct.new(id: "cs_test")
    end

    post checkout_url, params: { price_id: "price_test" }

    assert_response :success
    assert_equal "cs_test", JSON.parse(response.body)["sessionId"]
  ensure
    Stripe::Checkout::Session.define_singleton_method(:create, original_create)
  end

  test "create returns bad request when price_id is missing" do
    post checkout_url

    assert_response :bad_request
    assert_equal "missing price_id", JSON.parse(response.body)["error"]
  end

  test "success page renders" do
    get checkout_success_url

    assert_response :success
    assert_select "h1", "Payment successful"
  end

  test "cancel page renders" do
    get checkout_cancel_url

    assert_response :success
    assert_select "h1", "Payment canceled"
  end
end
