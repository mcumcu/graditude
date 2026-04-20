# frozen_string_literal: true

module GraditudeFactory
  module Certificates
    class Template
      attr_accessor :params, :pdf, :font_dir, :image_dir

      def initialize(params = {})
        @params = default_params.merge(params)
        @font_dir = GraditudeFactory.font_dir
        @image_dir = GraditudeFactory.image_dir
      end

      # Default parameters structure
      def default_params
        {
          graduate_name: nil,
          degree: nil,
          major: nil,
          nouns: [],
          honoree_name: nil,
          message: nil,
          presented_on: nil,
          signature_path: nil
        }
      end

      # Override in subclasses to define page setup
      def page_config
        {
          page_size: "LETTER",
          page_layout: :landscape,
          margin: [ 0, 0, 0, 0 ]
        }
      end

      # Override in subclasses
      def document_font
        raise NotImplementedError, "Subclass must implement document_font"
      end

      # Override in subclasses
      def template_assets
        {}
      end

      # Create the base Prawn document with styling
      def create_document
        config = page_config
        @pdf = PrawnRails::Document.new(
          page_size: config[:page_size],
          page_layout: config[:page_layout],
          margin: config[:margin]
        ) do |doc|
          doc.font(document_font)
          render_background(doc)
          render_header(doc)
        end
        self
      end

      # Override to render background
      def render_background(pdf)
        # Subclass implementation
      end

      # Override to render header/title
      def render_header(pdf)
        # Subclass implementation
      end

      # Main method to generate the certificate
      def generate
        create_document
        render_content(@pdf)
        @pdf
      end

      # Override to render main content
      def render_content(pdf)
        raise NotImplementedError, "Subclass must implement render_content"
      end

      # Helper dimensions
      def width
        @width ||= @pdf.bounds.width
      end

      def half_width
        width / 2.0
      end

      def margin_horizontal
        30.mm
      end

      def signature_width
        70.mm
      end

      protected

      def asset_path(type, filename)
        case type
        when :font
          File.join(@font_dir, filename)
        when :image
          File.join(@image_dir, filename)
        else
          filename
        end
      end
    end
  end
end
