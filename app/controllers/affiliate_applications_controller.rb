class AffiliateApplicationsController < ApplicationController
  before_action :require_invited_user
  before_action :set_application, only: :show

  def new
    if Current.user.affiliate_approved?
      redirect_to affiliate_path, notice: "You are already an approved affiliate."
      return
    end

    if Current.user.affiliate_application
      redirect_to affiliate_application_path
      return
    end

    @application = AffiliateApplication.new
  end

  def create
    if Current.user.affiliate_application
      redirect_to affiliate_application_path
      return
    end

    @application = Current.user.build_affiliate_application(
      affiliate_application_params.merge(affiliate_invitation: current_invitation)
    )

    if @application.valid?
      ActiveRecord::Base.transaction do
        @application.save!
        Current.user.update!(affiliate_status: "applied")
      end
      redirect_to affiliate_application_path, notice: "Your application has been submitted."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    unless @application
      redirect_to new_affiliate_application_path
    end
  end

  private
    def affiliate_application_params
      params.require(:affiliate_application).permit(:display_name, :audience, :promotion_method, :notes)
    end

    def set_application
      @application = Current.user.affiliate_application
    end

    def current_invitation
      @current_invitation ||= Current.user.affiliate_invitation
    end

    def require_invited_user
      invitation = current_invitation

      if invitation.nil? || !invitation.accepted? || invitation.revoked?
        redirect_to root_path, alert: "You need an invitation to apply as an affiliate."
        nil
      end
    end
end
