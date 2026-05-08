require "test_helper"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in
  end

  test "should get index" do
    get documents_index_url
    assert_response :success
  end

  test "should return inline preview data url for PNG index" do
    get documents_index_url(format: :png)

    assert_response :success
    assert_match %r{\Aurl\('data:image/png;base64,[A-Za-z0-9+/]+=*'\)\z}, @response.body
  end
end
