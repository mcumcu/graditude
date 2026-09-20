require "test_helper"

class AffiliateInvitationTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @user = User.create!(email_address: "test@example.com")
  end

  teardown do
    @user&.destroy
  end

  test "invitation_token returns a signed ID for pending invitation" do
    invitation = AffiliateInvitation.create!(email_address: @user.email_address)
    assert_not_nil invitation.invitation_token
    assert_instance_of String, invitation.invitation_token
  end

  test "invitation_token returns nil for revoked invitation" do
    invitation = AffiliateInvitation.create!(email_address: @user.email_address, status: "revoked")
    assert_nil invitation.invitation_token
  end

  test "invitation_token has reasonable length" do
    invitation = AffiliateInvitation.create!(email_address: @user.email_address)
    assert_operator invitation.invitation_token.length, :>=, 32
  end

  test "find_by_invitation_token! finds invitation by valid token" do
    invitation = AffiliateInvitation.create!(email_address: @user.email_address)
    token = invitation.invitation_token
    found = AffiliateInvitation.find_by_invitation_token!(token)
    assert_equal invitation, found
  end

  test "find_by_invitation_token! raises on invalid token" do
    assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
      AffiliateInvitation.find_by_invitation_token!("invalid_token")
    end
  end

  test "find_by_invitation_token! raises on expired token" do
    invitation = AffiliateInvitation.create!(email_address: @user.email_address, expires_at: 1.day.ago)
    token = invitation.invitation_token
    travel 2.seconds do
      assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
        AffiliateInvitation.find_by_invitation_token!(token)
      end
    end
  end

  test "expired? returns false for fresh pending invitation" do
    invitation = AffiliateInvitation.create!(email_address: @user.email_address)
    assert_not invitation.expired?
  end

  test "expired? returns true for past-due pending invitation" do
    invitation = AffiliateInvitation.create!(email_address: @user.email_address, expires_at: 1.day.ago)
    assert invitation.expired?
  end

  test "expired? returns false for accepted invitation regardless of expiration" do
    invitation = AffiliateInvitation.create!(email_address: @user.email_address)
    invitation.accept!(@user)
    assert_not invitation.expired?
  end

  test "expired? returns false when expires_at is nil" do
    invitation = AffiliateInvitation.new(email_address: @user.email_address)
    assert_not invitation.expired?
  end

  test "usable_for? returns true for pending invitation with matching user" do
    invitation = AffiliateInvitation.create!(email_address: @user.email_address)
    assert invitation.usable_for?(@user)
  end

  test "usable_for? returns false for non-matching user email" do
    invitation = AffiliateInvitation.create!(email_address: @user.email_address)
    other_user = User.create!(email_address: "other@example.com")
    assert_not invitation.usable_for?(other_user)
    other_user.destroy
  end

  test "usable_for? returns false for nil user" do
    invitation = AffiliateInvitation.create!(email_address: @user.email_address)
    assert_not invitation.usable_for?(nil)
  end

  test "usable_for? returns false for accepted invitation" do
    invitation = AffiliateInvitation.create!(email_address: @user.email_address)
    invitation.accept!(@user)
    assert_not invitation.usable_for?(@user)
  end

  test "usable_for? returns false for revoked invitation" do
    invitation = AffiliateInvitation.create!(email_address: @user.email_address, status: "revoked")
    assert_not invitation.usable_for?(@user)
  end

  test "usable_for? returns false for expired invitation" do
    invitation = AffiliateInvitation.create!(email_address: @user.email_address, expires_at: 1.day.ago)
    assert_not invitation.usable_for?(@user)
  end

  test "accept! updates status to accepted" do
    invitation = AffiliateInvitation.create!(email_address: @user.email_address)
    assert_equal "pending", invitation.status
    invitation.accept!(@user)
    assert invitation.reload.accepted?
  end

  test "accept! sets accepted_by and accepted_at" do
    invitation = AffiliateInvitation.create!(email_address: @user.email_address)
    invitation.accept!(@user)
    reloaded = invitation.reload
    assert_equal @user, reloaded.accepted_by
    assert_not_nil reloaded.accepted_at
    assert reloaded.accepted_at <= Time.current
  end

  test "accept! returns false for mismatched email" do
    invitation = AffiliateInvitation.create!(email_address: @user.email_address)
    other_user = User.create!(email_address: "other@example.com")
    result = invitation.accept!(other_user)
    assert_not result
    assert invitation.reload.pending?
    other_user.destroy
  end

  test "accept! returns false for already accepted" do
    invitation = AffiliateInvitation.create!(email_address: @user.email_address)
    invitation.accept!(@user)
    result = invitation.accept!(@user)
    assert_not result
  end

  test "accept! returns false for revoked invitation" do
    invitation = AffiliateInvitation.create!(email_address: @user.email_address, status: "revoked")
    result = invitation.accept!(@user)
    assert_not result
  end

  test "accept! returns false for expired invitation" do
    invitation = AffiliateInvitation.create!(email_address: @user.email_address, expires_at: 1.day.ago)
    result = invitation.accept!(@user)
    assert_not result
  end

  test "validates email_address presence" do
    invitation = AffiliateInvitation.new
    assert_not invitation.valid?
    assert_includes invitation.errors[:email_address], "can't be blank"
  end

  test "normalizes email_address to lowercase" do
    invitation = AffiliateInvitation.create!(email_address: "Test@Example.COM")
    assert_equal "test@example.com", invitation.reload.email_address
  end

  test "expires_at is set on create" do
    invitation = AffiliateInvitation.create!(email_address: @user.email_address)
    assert_not_nil invitation.expires_at
    assert_in_delta 14.days.from_now, invitation.expires_at, 10.seconds
  end

  test "accept! enforces unique acceptance per user via database constraint" do
    invitation1 = AffiliateInvitation.create!(email_address: @user.email_address)
    invitation2 = AffiliateInvitation.create!(email_address: @user.email_address)
    invitation1.accept!(@user)
    assert_raises(ActiveRecord::RecordNotUnique) do
      invitation2.accept!(@user)
    end
  end
end
