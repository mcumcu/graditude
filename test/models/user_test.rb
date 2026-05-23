require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "generates and resolves a magic link token" do
    user = users(:one)
    token = user.magic_link_token

    assert_equal user, User.find_by_magic_link_token!(token)
  end

  test "raises for invalid magic link token" do
    assert_raises ActiveSupport::MessageVerifier::InvalidSignature do
      User.find_by_magic_link_token!("invalid-token")
    end
  end

  test "referral token only resolves for approved affiliates" do
    user = users(:one)
    assert_nil user.referral_token
    assert_nil User.find_referrer_by_token("invalid-token")

    user.update!(affiliate_status: "approved")
    token = user.referral_token

    assert_equal user, User.find_referrer_by_token(token)
  end
end
