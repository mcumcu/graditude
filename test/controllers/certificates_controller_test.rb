require "test_helper"

class CertificatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @certificate = certificates(:one)
    sign_in
  end

  test "sign_in helper creates a Session record and authenticates protected routes" do
    sign_out

    assert_difference("Session.count") do
      sign_in users(:one)
    end

    assert_not_nil cookies["session_id"], "expected signed session cookie to be present after sign_in"

    get certificates_url
    assert_response :success
  end

  test "should get index" do
    get certificates_url
    assert_response :success
  end

  test "should get new" do
    get new_certificate_url
    assert_response :success

    assert_select "div.fixed"
    assert_select "div.absolute"
    assert_select "button[onclick=\"history.back()\"]", text: "✖︎"
    assert_select "form[action=\"/certificates\"]"
  end

  test "should create certificate" do
    assert_difference("Certificate.count") do
      post certificates_url, params: { certificate: { user_id: @certificate.user_id } }
    end

    new_certificate = Certificate.order(created_at: :desc).first
    assert_redirected_to certificate_url(new_certificate)
  end

  test "should show certificate" do
    get certificate_url(@certificate)
    assert_response :success
  end

  test "should get edit" do
    get edit_certificate_url(@certificate)
    assert_response :success

    assert_select "div.fixed"
    assert_select "div.absolute"
    assert_select "button[onclick=\"history.back()\"]", text: "✖︎"
    assert_select "form[action=\"/certificates/#{@certificate.id}\"]"
  end

  test "should update certificate" do
    patch certificate_url(@certificate), params: { certificate: { user_id: @certificate.user_id } }
    assert_redirected_to certificates_url
  end

  test "should destroy certificate" do
    assert_difference("Certificate.count", -1) do
      delete certificate_url(@certificate)
    end

    assert_redirected_to certificates_url
  end
end
