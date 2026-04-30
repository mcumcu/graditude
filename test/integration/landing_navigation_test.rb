require "test_helper"

class LandingNavigationTest < ActionDispatch::IntegrationTest
  test "landing page includes sign in and sign up navigation links" do
    get root_url

    assert_response :success
    assert_select "a", text: "Sign in"
    assert_select "a", text: "Sign up"
    assert_select "a[href='#{new_signup_path}']"
  end

  test "signup route renders the signup modal" do
    get new_signup_path, as: :html

    assert_response :success
    assert_select "h2", /Sign up/
    assert_select "label", text: "Email address"
  end
end
