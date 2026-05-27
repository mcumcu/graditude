class User < ApplicationRecord
  has_secure_password validations: false
  has_many :sessions, dependent: :destroy
  has_many :carts, dependent: :destroy
  has_one :open_cart, -> { where(status: :open) }, class_name: "Cart"
  has_many :orders, dependent: :destroy
  has_many :certificates, dependent: :destroy
  has_many :affiliate_invitations_sent, class_name: "AffiliateInvitation", foreign_key: :invited_by_id, dependent: :nullify
  has_one :affiliate_invitation, class_name: "AffiliateInvitation", foreign_key: :accepted_by_id, dependent: :nullify
  has_one :affiliate_application, dependent: :destroy
  has_many :referrals, class_name: "User", foreign_key: :referred_by_id, dependent: :nullify
  belongs_to :referred_by, class_name: "User", optional: true
  belongs_to :affiliate_approved_by, class_name: "User", optional: true

  attribute :affiliate_status, :string, default: "inactive"

  enum :affiliate_status, {
    inactive: "inactive",
    applied: "applied",
    approved: "approved",
    rejected: "rejected"
  }

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :email_address, presence: true, uniqueness: true

  before_create :assign_referrer

  def magic_link_token
    signed_id(purpose: "magic_link", expires_in: 15.minutes)
  end

  def self.find_by_magic_link_token!(token)
    find_signed!(token, purpose: "magic_link")
  end

  def referral_token(expires_in: 30.days)
    return unless affiliate_approved?

    signed_id(purpose: "referral", expires_in: expires_in)
  end

  def affiliate_approved?
    affiliate_status == "approved"
  end

  def approve_affiliate!(reviewer: nil)
    update!(
      affiliate_status: "approved",
      affiliate_approved_at: Time.current,
      affiliate_approved_by: reviewer
    )
  end

  def reject_affiliate!(reviewer: nil)
    update!(
      affiliate_status: "rejected",
      affiliate_approved_at: nil,
      affiliate_approved_by: nil
    )
  end

  def self.find_referrer_by_token(token)
    user = find_signed(token, purpose: "referral")
    return unless user&.affiliate_approved?

    user
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageVerifier::InvalidMessage
    nil
  end

  private
    def assign_referrer
      return unless Current.affiliate

      self.referred_by = Current.affiliate
      self.referred_at = Time.current
    end
end
