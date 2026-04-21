require "test_helper"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in
  end

  test "should get index" do
    get documents_index_url
    assert_response :success
  end
end
