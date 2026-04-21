# frozen_string_literal: true

require "active_support/concern"

# Load Prawn dependencies immediately to ensure Integer#mm is available
begin
  require "prawn"
  require "prawn/measurement_extensions"  # Adds .mm, .pt, .in, etc. to Integer
  require "prawn-rails"
  require "prawn-svg"
  require "pdftoimage"
rescue LoadError => e
  warn "GraditudeFactory dependencies: #{e.message}"
end

require_relative "graditude_factory/version"

module GraditudeFactory
  class Error < StandardError; end

  ASSET_DIR = File.join(__dir__, "graditude_factory", "assets").freeze
  FONT_DIR = File.join(ASSET_DIR, "fonts").freeze
  IMG_DIR = File.join(ASSET_DIR, "images").freeze

  # Configuration
  class << self
    attr_accessor :font_dir, :image_dir

    def font_dir
      @font_dir ||= FONT_DIR
    end

    def image_dir
      @image_dir ||= IMG_DIR
    end

    def configure
      yield self if block_given?
    end
  end
end

require_relative "graditude_factory/concerns/printable"
require_relative "graditude_factory/certificates/template"
require_relative "graditude_factory/certificates/penn_template"
require_relative "graditude_factory/certificates/westtown_template"
require_relative "graditude_factory/certificates/boulder_template"
