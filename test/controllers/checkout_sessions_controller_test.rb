require "test_helper"

class CheckoutSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @checkout_session = checkout_sessions(:one)
  end

  test "should get new" do
    sign_in
    get new_checkout_url
    assert_response :success
  end
end
