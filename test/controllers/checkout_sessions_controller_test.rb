require "test_helper"

class CheckoutSessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    sign_in
    get new_checkout_url
    assert_response :success
  end
end
