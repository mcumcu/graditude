require "test_helper"

class AffiliateApplicationTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "test@example.com")
  end

  teardown do
    AffiliateApplication.where(user: @user).destroy_all
    @user.destroy
  end

  test "should be valid with required attributes" do
    application = AffiliateApplication.create!(
      user: @user,
      display_name: "Test User",
      audience: "Friends and family",
      promotion_method: "Email list"
    )
    assert application.persisted?
  end

  test "should be invalid with missing user" do
    application = AffiliateApplication.new(
      display_name: "Test User",
      audience: "Friends and family",
      promotion_method: "Email list"
    )
    assert_not application.valid?
    assert_includes application.errors[:user], "can't be blank"
  end

  test "should be invalid with missing display_name" do
    application = AffiliateApplication.new(
      user: @user,
      audience: "Friends and family",
      promotion_method: "Email list"
    )
    assert_not application.valid?
    assert_includes application.errors[:display_name], "can't be blank"
  end

  test "should be invalid with missing audience" do
    application = AffiliateApplication.new(
      user: @user,
      display_name: "Test User",
      promotion_method: "Email list"
    )
    assert_not application.valid?
    assert_includes application.errors[:audience], "can't be blank"
  end

  test "should be invalid with missing promotion_method" do
    application = AffiliateApplication.new(
      user: @user,
      display_name: "Test User",
      audience: "Friends and family"
    )
    assert_not application.valid?
    assert_includes application.errors[:promotion_method], "can't be blank"
  end

  test "default status is submitted" do
    application = AffiliateApplication.new(
      user: @user,
      display_name: "Test User",
      audience: "Friends and family",
      promotion_method: "Email list"
    )
    assert_equal "submitted", application.status
  end

  test "valid statuses are submitted approved and rejected" do
    assert_includes AffiliateApplication.statuses.keys, "submitted"
    assert_includes AffiliateApplication.statuses.keys, "approved"
    assert_includes AffiliateApplication.statuses.keys, "rejected"
  end

  test "set_submitted_at sets submitted_at on create" do
    application = AffiliateApplication.create!(
      user: @user,
      display_name: "Test User",
      audience: "Friends and family",
      promotion_method: "Email list"
    )
    assert_not_nil application.submitted_at
    assert application.submitted_at <= Time.current
  end

  test "approve! updates status to approved" do
    application = AffiliateApplication.create!(
      user: @user,
      display_name: "Test User",
      audience: "Friends and family",
      promotion_method: "Email list"
    )
    assert_equal "submitted", application.status
    application.approve!
    assert application.reload.approved?
  end

  test "approve! updates user affiliate_status to approved" do
    application = AffiliateApplication.create!(
      user: @user,
      display_name: "Test User",
      audience: "Friends and family",
      promotion_method: "Email list"
    )
    assert_equal "inactive", @user.reload.affiliate_status
    application.approve!
    assert_equal "approved", @user.reload.affiliate_status
  end

  test "approve! sets affiliate_approved_at and affiliate_approved_by" do
    reviewer = User.create!(email_address: "reviewer@example.com")
    application = AffiliateApplication.create!(
      user: @user,
      display_name: "Test User",
      audience: "Friends and family",
      promotion_method: "Email list"
    )
    application.approve!(reviewer: reviewer)
    @user.reload
    assert_not_nil @user.affiliate_approved_at
    assert_equal reviewer, @user.affiliate_approved_by
    application.destroy
  end

  test "approve! returns false for already approved application" do
    application = AffiliateApplication.create!(
      user: @user,
      display_name: "Test User",
      audience: "Friends and family",
      promotion_method: "Email list"
    )
    application.approve!
    result = application.approve!
    assert_not result
  end

  test "approve! returns false for rejected application" do
    application = AffiliateApplication.create!(
      user: @user,
      status: "rejected",
      display_name: "Test User",
      audience: "Friends and family",
      promotion_method: "Email list"
    )
    result = application.approve!
    assert_not result
  end

  test "reject! updates status to rejected" do
    application = AffiliateApplication.create!(
      user: @user,
      display_name: "Test User",
      audience: "Friends and family",
      promotion_method: "Email list"
    )
    assert_equal "submitted", application.status
    application.reject!
    assert application.reload.rejected?
  end

  test "reject! updates user affiliate_status to rejected" do
    application = AffiliateApplication.create!(
      user: @user,
      display_name: "Test User",
      audience: "Friends and family",
      promotion_method: "Email list"
    )
    assert_equal "inactive", @user.reload.affiliate_status
    application.reject!
    assert_equal "rejected", @user.reload.affiliate_status
  end

  test "reject! clears affiliate_approved_at and affiliate_approved_by" do
    @user.update!(affiliate_status: "approved", affiliate_approved_at: Time.current, affiliate_approved_by: users(:admin))
    application = AffiliateApplication.create!(
      user: @user,
      display_name: "Test User",
      audience: "Friends and family",
      promotion_method: "Email list"
    )
    application.reject!
    @user.reload
    assert_nil @user.affiliate_approved_at
    assert_nil @user.affiliate_approved_by
  end

  test "reject! returns false for already rejected application" do
    application = AffiliateApplication.create!(
      user: @user,
      status: "rejected",
      display_name: "Test User",
      audience: "Friends and family",
      promotion_method: "Email list"
    )
    application.reject!
    result = application.reject!
    assert_not result
  end

  test "reject! returns false for approved application" do
    application = AffiliateApplication.create!(
      user: @user,
      status: "approved",
      display_name: "Test User",
      audience: "Friends and family",
      promotion_method: "Email list"
    )
    result = application.reject!
    assert_not result
  end

  test "approve! and reject! are transactional" do
    application = AffiliateApplication.create!(
      user: @user,
      display_name: "Test User",
      audience: "Friends and family",
      promotion_method: "Email list"
    )
    original_status = @user.reload.affiliate_status
    application.approve!
    assert_equal "approved", application.reload.status
    assert_equal "approved", @user.reload.affiliate_status
  end

  test "unique constraint on user_id prevents duplicate applications" do
    AffiliateApplication.create!(
      user: @user,
      display_name: "Test User",
      audience: "Friends and family",
      promotion_method: "Email list"
    )
    assert_raises(ActiveRecord::RecordNotUnique) do
      AffiliateApplication.create!(
        user: @user,
        display_name: "Second User",
        audience: "Friends and family",
        promotion_method: "Email list"
      )
    end
  end
end
