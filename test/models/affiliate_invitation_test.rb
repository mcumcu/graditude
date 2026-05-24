require "test_helper"

class AffiliateInvitationTest < ActiveSupport::TestCase
  test "generates and resolves an invitation token" do
    invitation = AffiliateInvitation.create!(email_address: "invitee@example.com")
    token = invitation.invitation_token

    assert_equal invitation, AffiliateInvitation.find_by_invitation_token!(token)
  end

  test "accepts only when email matches" do
    invitation = AffiliateInvitation.create!(email_address: "invitee@example.com")
    user = users(:one)

    refute invitation.accept!(user)
    assert invitation.pending?

    invitation.update!(email_address: user.email_address)
    assert invitation.accept!(user)
    assert invitation.accepted?
    assert_equal user, invitation.accepted_by
  end
end
