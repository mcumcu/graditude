class AffiliateInvitationMailer < ApplicationMailer
  def invite(invitation)
    @invitation = invitation
    @accept_url = affiliate_invitation_url(token: @invitation.invitation_token)
    mail subject: "You are invited to apply as an affiliate", to: @invitation.email_address
  end
end
