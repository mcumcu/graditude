require "test_helper"

class AffiliateApplicationTest < ActiveSupport::TestCase
  test "approve updates user affiliate status" do
    user = users(:one)
    reviewer = users(:two)
    application = AffiliateApplication.create!(
      user: user,
      display_name: "Graditude Partner",
      audience: "Friends and family",
      promotion_method: "Email list"
    )

    application.approve!(reviewer: reviewer)

    assert application.reload.approved?
    assert user.reload.affiliate_approved?
    assert_equal reviewer, application.reviewed_by
  end

  test "reject updates user affiliate status" do
    user = users(:one)
    reviewer = users(:two)
    application = AffiliateApplication.create!(
      user: user,
      display_name: "Graditude Partner",
      audience: "Friends and family",
      promotion_method: "Email list"
    )

    application.reject!(reviewer: reviewer)

    assert application.reload.rejected?
    assert_equal "rejected", user.reload.affiliate_status
    assert_equal reviewer, application.reviewed_by
  end
end
