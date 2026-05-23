require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "creates a magic link for a new user" do
    assert_difference "User.count", 1 do
      assert_enqueued_emails 1 do
        post session_url, params: { email_address: "new@example.com" }
      end
    end

    assert_redirected_to new_session_path
    assert_equal "Check your inbox for a sign-in link", flash[:notice]
    assert User.exists?(email_address: "new@example.com")
  end

  test "new session page uses referer for close button when present" do
    get new_session_url, headers: { "HTTP_REFERER" => "/landing" }

    assert_response :success
    assert_select "button[onclick=\"window.location='/landing'\"]", text: "✖︎"
  end

  test "new signup page uses referer for close button when present" do
    get new_signup_url, headers: { "HTTP_REFERER" => "/landing" }

    assert_response :success
    assert_select "button[onclick=\"window.location='/landing'\"]", text: "✖︎"
  end

  test "creates a magic link for an existing user" do
    user = users(:one)

    assert_enqueued_emails 1 do
      post session_url, params: { email_address: user.email_address }
    end

    assert_redirected_to new_session_path
    assert_equal "Check your inbox for a sign-in link", flash[:notice]
  end

  test "authenticates with a valid magic link" do
    user = users(:one)
    token = user.magic_link_token

    get authenticate_session_url(token: token)

    assert_redirected_to root_url
    assert_equal "Signed in.", flash[:notice]
    assert cookies["session_id"].present?
  end

  test "creates a referred user when a referral token is present" do
    referrer = users(:one)
    referrer.update!(affiliate_status: "approved")
    referral_token = referrer.referral_token

    get root_url(ref: referral_token)

    post session_url, params: { email_address: "referred@example.com" }

    referred_user = User.find_by(email_address: "referred@example.com")
    assert_equal referrer, referred_user.referred_by
    assert_not_nil referred_user.referred_at
  end

  test "rejects an invalid magic link" do
    get authenticate_session_url(token: "invalid-token")

    assert_redirected_to new_session_path
    assert_equal "That sign-in link is invalid or has expired", flash[:alert]
  end
end
