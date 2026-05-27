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

  test "sign in email uses configured app url" do
    user = users(:one)
    original_url_options = Rails.application.config.action_mailer.default_url_options
    Rails.application.config.action_mailer.default_url_options = {
      host: "9796-108-16-205-147.ngrok-free.app",
      protocol: "https"
    }

    mail = MagicLinkMailer.sign_in(user)

    assert_includes mail.text_part.body.decoded, "https://9796-108-16-205-147.ngrok-free.app/session/authenticate/"
    assert_includes mail.html_part.body.decoded, "https://9796-108-16-205-147.ngrok-free.app/session/authenticate/"
  ensure
    Rails.application.config.action_mailer.default_url_options = original_url_options
  end
end
