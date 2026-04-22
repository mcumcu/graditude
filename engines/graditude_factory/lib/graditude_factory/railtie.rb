# frozen_string_literal: true

module GraditudeFactory
  class Railtie < Rails::Railtie
    # Railtie ensures the gem is properly integrated with Rails
    # All Prawn dependencies are loaded in the main graditude_factory.rb file
    # during gem initialization
  end
end
