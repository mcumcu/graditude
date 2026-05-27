class ApplicationMailer < ActionMailer::Base
  default from: "info@thegraditude.com"
  layout "mailer"

  private

  def default_url_options
    Rails.application.config.action_mailer.default_url_options.to_h.symbolize_keys
  end
end
