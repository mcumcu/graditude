require "test_helper"

class AffiliateApplicationsControllerTest < ActionDispatch::IntegrationTest
  test "invited users can view the application form" do
    user = users(:one)
    invitation = AffiliateInvitation.create!(email_address: user.email_address)
    invitation.accept!(user)

    sign_in user
    get new_affiliate_application_url

    assert_response :success
    assert_select "h2", /Affiliate Application/
  end

  test "non-invited users are redirected" do
    user = users(:one)

    sign_in user
    get new_affiliate_application_url

    assert_redirected_to root_path
    assert_equal "You need an invitation to apply as an affiliate.", flash[:alert]
  end

  test "creates an affiliate application and updates user status" do
    user = users(:one)
    invitation = AffiliateInvitation.create!(email_address: user.email_address)
    invitation.accept!(user)

    sign_in user

    assert_difference "AffiliateApplication.count", 1 do
      post affiliate_application_url, params: {
        affiliate_application: {
          display_name: "Graditude Partner",
          audience: "Friends and family",
          promotion_method: "Email list",
          notes: "Looking forward to helping."
        }
      }
    end

    assert_redirected_to affiliate_application_path
    assert_equal "applied", user.reload.affiliate_status
  end
end
