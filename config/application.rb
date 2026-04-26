require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Graditude
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    #

    # Use UUIDs as default primary keys
    config.generators do |generator|
      generator.orm :active_record, primary_key_type: :uuid
    end

    config.after_initialize do
      next unless Rails.env.production?

      stripe_secret_key = ENV["STRIPE_KEY"]
      stripe_publishable_key = ENV["STRIPE_KEY_PUB"]

      secret_valid = stripe_secret_key.is_a?(String) && stripe_secret_key.start_with?("sk_")
      publishable_valid = stripe_publishable_key.is_a?(String) && stripe_publishable_key.start_with?("pk_")

      unless secret_valid && publishable_valid
        error_details = []
        error_details << "STRIPE_KEY is missing" unless stripe_secret_key.present?
        error_details << "STRIPE_KEY does not start with 'sk_'" if stripe_secret_key.present? && !secret_valid
        error_details << "STRIPE_KEY_PUB is missing" unless stripe_publishable_key.present?
        error_details << "STRIPE_KEY_PUB does not start with 'pk_'" if stripe_publishable_key.present? && !publishable_valid

        message = <<~ERROR_MESSAGE.strip
          Stripe configuration failed validation:
          #{error_details.join("; ")}
          Please set valid Stripe keys in .env.local or your environment.
        ERROR_MESSAGE

        Rails.logger.error(message)
        raise RuntimeError, message
      end

      stripe_message = "≈ Stripe config validated 💵"
      STDOUT.puts(stripe_message)
      Rails.logger.info(stripe_message)
    end
  end
end
