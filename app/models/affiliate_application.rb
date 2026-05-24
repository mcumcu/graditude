class AffiliateApplication < ApplicationRecord
  belongs_to :user
  belongs_to :affiliate_invitation, optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true

  validates :user, presence: true
  validates :status, presence: true
  validates :display_name, :audience, :promotion_method, presence: true

  enum :status, {
    submitted: "submitted",
    approved: "approved",
    rejected: "rejected"
  }

  before_validation :set_submitted_at, on: :create

  def approve!(reviewer: nil)
    transaction do
      update!(status: "approved", reviewed_at: Time.current, reviewed_by: reviewer)
      user.approve_affiliate!(reviewer: reviewer)
    end
  end

  def reject!(reviewer: nil)
    transaction do
      update!(status: "rejected", reviewed_at: Time.current, reviewed_by: reviewer)
      user.reject_affiliate!(reviewer: reviewer)
    end
  end

  private
    def set_submitted_at
      self.submitted_at ||= Time.current
    end
end
