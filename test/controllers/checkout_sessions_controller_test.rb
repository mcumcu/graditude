require "test_helper"

class CheckoutSessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get checkout_sessions_show_url
    assert_response :success
  end

  test "should get create" do
    get checkout_sessions_create_url
    assert_response :success
  end
end
