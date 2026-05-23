class AffiliateInvitation < ApplicationRecord
  belongs_to :invited_by, class_name: "User", optional: true
  belongs_to :accepted_by, class_name: "User", optional: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :email_address, presence: true

  enum :status, {
    pending: "pending",
    accepted: "accepted",
    revoked: "revoked"
  }

  before_validation :set_expires_at, on: :create

  def invitation_token
    return if revoked?

    signed_id(purpose: "affiliate_invitation", expires_in: token_expires_in)
  end

  def self.find_by_invitation_token!(token)
    find_signed!(token, purpose: "affiliate_invitation")
  end

  def expired?
    return false if accepted?

    expires_at.present? && expires_at <= Time.current
  end

  def usable_for?(user)
    pending? && !expired? && user&.email_address == email_address
  end

  def accept!(user)
    return false unless usable_for?(user)

    update!(accepted_by: user, accepted_at: Time.current, status: "accepted")
  end

  private
    def set_expires_at
      self.expires_at ||= 14.days.from_now
    end

    def token_expires_in
      return 14.days if expires_at.blank?

      [ expires_at - Time.current, 1.second ].max
    end
end
