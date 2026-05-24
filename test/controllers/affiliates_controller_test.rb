require "test_helper"

class AffiliatesControllerTest < ActionDispatch::IntegrationTest
  test "approved affiliates can view their referral link" do
    user = users(:one)
    user.update!(affiliate_status: "approved")

    sign_in user
    get affiliate_url

    assert_response :success
    assert_match(/ref=/, response.body)
  end

  test "non-approved users are redirected" do
    user = users(:one)

    sign_in user
    get affiliate_url

    assert_redirected_to root_path
    assert_equal "You do not have access to the affiliate page.", flash[:alert]
  end
end
