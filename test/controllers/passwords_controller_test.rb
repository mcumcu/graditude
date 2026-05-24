require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  test "new password page uses referer for close button when present" do
    get new_password_url, headers: { "HTTP_REFERER" => "/landing" }

    assert_response :success
    assert_select "a[aria-label='Close dialog'][href='/landing']", text: "✖︎"
  end

  test "edit password page uses referer for close button when present" do
    user = users(:one)
    original = User.singleton_class.instance_method(:find_by_password_reset_token!) if User.singleton_class.method_defined?(:find_by_password_reset_token!)

    User.singleton_class.define_method(:find_by_password_reset_token!) do |token|
      user
    end

    get edit_password_url(token: "token"), headers: { "HTTP_REFERER" => "/landing" }

    assert_response :success
    assert_select "a[aria-label='Close dialog'][href='/landing']", text: "✖︎"
  ensure
    if original
      User.singleton_class.define_method(:find_by_password_reset_token!, original)
    else
      User.singleton_class.send(:remove_method, :find_by_password_reset_token!)
    end
  end
end
