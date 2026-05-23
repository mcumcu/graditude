class AffiliatesController < ApplicationController
  before_action :require_approved_affiliate

  def show
    @referral_url = root_url(ref: Current.user.referral_token)
  end

  private
    def require_approved_affiliate
      return if Current.user&.affiliate_approved?

      redirect_to root_path, alert: "You do not have access to the affiliate page."
      nil
    end
end
