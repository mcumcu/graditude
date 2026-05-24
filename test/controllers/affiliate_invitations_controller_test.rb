require "test_helper"

class AffiliateInvitationsControllerTest < ActionDispatch::IntegrationTest
  test "unauthenticated users are routed to sign in" do
    invitation = AffiliateInvitation.create!(email_address: "invitee@example.com")

    get affiliate_invitation_url(token: invitation.invitation_token)

    assert_redirected_to new_session_path
    assert_equal "Sign in to continue your affiliate application.", flash[:info]
  end

  test "authenticated users with matching email can accept" do
    user = users(:one)
    invitation = AffiliateInvitation.create!(email_address: user.email_address)

    sign_in user
    get affiliate_invitation_url(token: invitation.invitation_token)

    assert_redirected_to new_affiliate_application_path
    assert invitation.reload.accepted?
    assert_equal user, invitation.accepted_by
  end

  test "authenticated users with mismatched email are rejected" do
    user = users(:one)
    invitation = AffiliateInvitation.create!(email_address: "other@example.com")

    sign_in user
    get affiliate_invitation_url(token: invitation.invitation_token)

    assert_redirected_to root_path
    assert invitation.reload.pending?
  end
end
