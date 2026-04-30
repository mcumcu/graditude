class MagicLinkMailer < ApplicationMailer
  def sign_in(user)
    @user = user
    @magic_link_url = authenticate_session_url(token: @user.magic_link_token)
    mail subject: "Your sign-in link", to: @user.email_address
  end
end
