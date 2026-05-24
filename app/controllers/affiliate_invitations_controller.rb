class AffiliateInvitationsController < ApplicationController
  allow_unauthenticated_access only: :show

  def show
    invitation = AffiliateInvitation.find_by_invitation_token!(params.expect(:token))

    if invitation.revoked? || invitation.expired?
      redirect_to root_path, alert: "That invitation has expired."
      return
    end

    if Current.user
      session.delete(:pending_affiliate_invitation_id)

      if invitation.accepted?
        if invitation.accepted_by == Current.user
          redirect_to new_affiliate_application_path, notice: "Invitation already accepted."
        else
          redirect_to root_path, alert: "That invitation has already been used."
        end
        return
      end

      if invitation.accept!(Current.user)
        redirect_to new_affiliate_application_path, notice: "Invitation accepted."
      else
        redirect_to root_path, alert: "That invitation does not match your email address."
      end
    else
      session[:pending_affiliate_invitation_id] = invitation.id
      session[:return_to_after_authenticating] = new_affiliate_application_url
      redirect_to new_session_path, flash: { info: "Sign in to continue your affiliate application." }
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageVerifier::InvalidMessage, ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "That invitation link is invalid or has expired."
  end
end
