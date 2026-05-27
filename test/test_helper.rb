ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "ostruct"

module ActiveSupport
  class TestCase
    # Run tests sequentially by default to avoid process-fork instability on some macOS/Ruby/PostgreSQL setups.
    # Set PARALLEL_WORKERS to a higher number when parallel test execution is stable in your environment.
    parallelize(workers: ENV.fetch("PARALLEL_WORKERS", 1).to_i)

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

  def stub_stripe_price_retrieve(stripe_price)
    original_retrieve = Stripe::Price.method(:retrieve)
    Stripe::Price.define_singleton_method(:retrieve) { |_price_id| stripe_price }

    yield
  ensure
    Stripe::Price.define_singleton_method(:retrieve, original_retrieve)
  end

  def stub_stripe_product_retrieve(stripe_product)
    original_retrieve = Stripe::Product.method(:retrieve)
    Stripe::Product.define_singleton_method(:retrieve) { |_product_id| stripe_product }

    yield
  ensure
    Stripe::Product.define_singleton_method(:retrieve, original_retrieve)
  end

  def stub_stripe_product_and_price_retrieve(stripe_product, stripe_price = nil)
    original_product_retrieve = Stripe::Product.method(:retrieve)
    original_price_retrieve = Stripe::Price.method(:retrieve)

    Stripe::Product.define_singleton_method(:retrieve) { |_product_id| stripe_product }
    Stripe::Price.define_singleton_method(:retrieve) { |_price_id| stripe_price } if stripe_price

    yield
  ensure
    Stripe::Product.define_singleton_method(:retrieve, original_product_retrieve)
    Stripe::Price.define_singleton_method(:retrieve, original_price_retrieve) if stripe_price
  end

  def start_stubbed_stripe_products_for_webhooks
    @stripe_product_retrieve_original = Stripe::Product.method(:retrieve)
    @stripe_price_retrieve_original = Stripe::Price.method(:retrieve)

    Stripe::Product.define_singleton_method(:retrieve) do |product_id|
      product = Product.find_by(stripe_product_id: product_id)
      cache = product&.stripe_product_cache || {}
      metadata = cache.fetch("metadata", {})
      metadata = {} unless metadata.is_a?(Hash)
      metadata["format"] ||= "framed"

      default_price = cache["default_price"] || "price_stub"
      name = cache["name"] || "Webhook Product"
      description = cache["description"] || "Webhook description"

      OpenStruct.new(
        id: product_id,
        name: name,
        description: description,
        metadata: metadata,
        default_price: default_price,
        to_hash: {
          "id" => product_id,
          "name" => name,
          "description" => description,
          "metadata" => metadata,
          "default_price" => default_price
        }
      )
    end

    Stripe::Price.define_singleton_method(:retrieve) do |price_id|
      OpenStruct.new(
        id: price_id,
        unit_amount: 2500,
        currency: "usd",
        to_hash: {
          "id" => price_id,
          "unit_amount" => 2500,
          "currency" => "usd"
        }
      )
    end
  end

  def stop_stubbed_stripe_products_for_webhooks
    if defined?(@stripe_product_retrieve_original) && @stripe_product_retrieve_original
      Stripe::Product.define_singleton_method(:retrieve, @stripe_product_retrieve_original)
    end
    if defined?(@stripe_price_retrieve_original) && @stripe_price_retrieve_original
      Stripe::Price.define_singleton_method(:retrieve, @stripe_price_retrieve_original)
    end

    @stripe_product_retrieve_original = nil
    @stripe_price_retrieve_original = nil
  end

  def with_stubbed_stripe_products_for_webhooks
    start_stubbed_stripe_products_for_webhooks
    yield
  ensure
    stop_stubbed_stripe_products_for_webhooks
  end

  def sign_out
    delete session_url
    follow_redirect! if response.redirect?
  rescue ActionController::UrlGenerationError
    # If the route is unavailable in a broken auth path, fall back to direct cookie cleanup.
  ensure
    cookies.delete(:session_id)
  end
end
