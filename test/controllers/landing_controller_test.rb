require "test_helper"

class LandingControllerTest < ActionDispatch::IntegrationTest
  test "should get landing with hero elements" do
    get root_url
    assert_response :success

    assert_select "#hero-info"
    assert_select "#hero-landing"
    assert_select "#hero-copy"
    assert_select "#hero-cta"
    assert_select "#hero-image"
  end
end
