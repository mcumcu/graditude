require "test_helper"

class MagicLinkMailerTest < ActionMailer::TestCase
  test "sign in email contains the sign-in url" do
    user = users(:one)
    mail = MagicLinkMailer.sign_in(user)

    assert_equal [ user.email_address ], mail.to
    assert_equal "Your sign-in link", mail.subject
    assert_match /sign in/i, mail.body.encoded
    assert_match %r{/session/authenticate/}, mail.body.encoded
  end
end
