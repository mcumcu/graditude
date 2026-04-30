class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create new_signup authenticate ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Try again later." }

  def new
  end

  def new_signup
  end

  def create
    email_address = params[:email_address].to_s.strip.downcase

    if email_address.blank?
      redirect_to new_session_path, alert: "Enter your email address."
      return
    end

    user = User.find_or_create_by!(email_address: email_address)
    MagicLinkMailer.sign_in(user).deliver_later

    redirect_to new_session_path, notice: "Check your inbox for a sign-in link."
  end

  def authenticate
    user = User.find_by_magic_link_token!(params[:token])
    start_new_session_for user
    redirect_to after_authentication_url, notice: "Signed in."
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageVerifier::InvalidMessage, ActiveRecord::RecordNotFound
    redirect_to new_session_path, alert: "That sign-in link is invalid or has expired."
  end

  def destroy
    terminate_session
    redirect_to new_session_path
  end
end
