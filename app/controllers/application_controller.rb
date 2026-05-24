class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_current_affiliate

  private
    def set_current_affiliate
      token = params[:ref].presence || session[:affiliate_referral_token]
      return if token.blank?

      affiliate = User.find_referrer_by_token(token)
      if affiliate
        Current.affiliate = affiliate
        session[:affiliate_referral_token] = token
      elsif params[:ref].present?
        session.delete(:affiliate_referral_token)
      end
    end
end
