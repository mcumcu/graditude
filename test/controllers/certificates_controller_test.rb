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
    assert_select "button[onclick=\"window.location='/certificates'\"]", text: "✖︎"
    assert_select "form[action=\"/certificates\"]"
  end

  test "should create certificate" do
    assert_difference("Certificate.count") do
      post certificates_url, params: {
        certificate: {
          graduate_name: "New Grad",
          honoree_name: "Honoree Recipient",
          degree: "Bachelor of Science",
          presented_on: "2026-05-15"
        }
      }
    end

    new_certificate = Certificate.order(created_at: :desc).first
    assert_redirected_to certificate_url(new_certificate)
    assert_equal @certificate.user_id, new_certificate.user_id
  end

  test "should return bad request when certificate params are missing" do
    assert_no_difference("Certificate.count") do
      post certificates_url, params: {}
    end

    assert_response :bad_request
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
    assert_select "button[onclick=\"window.location='/certificates'\"]", text: "✖︎"
    assert_select "form[action=\"/certificates/#{@certificate.id}\"]"
  end

  test "should update certificate" do
    patch certificate_url(@certificate), params: { certificate: { graduate_name: "Updated Grad" } }
    assert_redirected_to certificates_url

    @certificate.reload
    assert_equal "Updated Grad", @certificate.graduate_name
  end

  test "should destroy certificate" do
    assert_difference("Certificate.count", -1) do
      delete certificate_url(@certificate)
    end

    assert_redirected_to certificates_url
  end
end
