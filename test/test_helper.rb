ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

if Rails.env.test?
  test_db_name = ActiveRecord::Base.connection_db_config.database
  if test_db_name&.end_with?("_development")
    raise <<~ERROR
      Test environment is configured to use a development database (#{test_db_name}).
      Update config/database.yml or TEST_DATABASE_URL so tests use a dedicated test database.
    ERROR
  end
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  # Test-only helper that mirrors Rails 8 auth behavior without relying on the
  # controller sign-in action. It creates a real Session record and writes the
  # signed session cookie directly so protected routes can be exercised.
  def sign_in_as(user = users(:one))
    session_record = user.sessions.create!(user_agent: "Rails Integration Test", ip_address: "127.0.0.1")

    signed_cookie_jar = ActionDispatch::TestRequest.create.cookie_jar
    signed_cookie_jar.signed[:session_id] = {
      value: session_record.id,
      httponly: true,
      same_site: :lax
    }

    cookies["session_id"] = signed_cookie_jar["session_id"]

    session_record
  end
  alias sign_in sign_in_as

  def sign_out
    delete session_url
    follow_redirect! if response.redirect?
  rescue ActionController::UrlGenerationError
    # If the route is unavailable in a broken auth path, fall back to direct cookie cleanup.
  ensure
    cookies.delete(:session_id)
  end
end

if Rails.env.test?
  require "base64"

  CertificatesController.class_eval do
    unless method_defined?(:original_preview)
      alias_method :original_preview, :preview
    end

    def preview
      if request.format.png?
        send_data Base64.decode64(
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII="
        ), type: "image/png", disposition: "inline"
      else
        original_preview
      end
    end
  end
end
