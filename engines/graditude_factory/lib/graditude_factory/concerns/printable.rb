# frozen_string_literal: true

require "fileutils"

module GraditudeFactory
  module Concerns
    module Printable
      extend ActiveSupport::Concern

      included do
        # Code executed when the concern is included in a controller
      end

      # Default parameters for certificate generation
      def default_certificate_params
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

      # Generate a PDF using the specified template class
      # @param template_class [Class] A subclass of GraditudeFactory::Certificates::Template
      # @param params [Hash] Parameters for the certificate
      # @return [Prawn::Document] The generated PDF document
      def generate_certificate_pdf(template_class, params = {})
        template = template_class.new(params)
        template.generate
      end

      # Render a PNG from a PDF
      # @param pdf_path [String] Path to the PDF file
      # @param png_path [String] Path where PNG should be saved
      # @return [String] Path to the generated PNG
      def render_certificate_png(pdf_path, png_path)
        page = PDFToImage.open(pdf_path).first

        if page
          FileUtils.mkdir_p(File.dirname(png_path))
          page.resize("1024").save(png_path)
        end

        png_path
      end

      # Temporary directory for PDFs
      def temp_pdf_dir
        @temp_pdf_dir ||= Rails.root.join("tmp", "preview", "pdf")
      end

      # Temporary directory for PNGs
      def temp_png_dir
        @temp_png_dir ||= Rails.root.join("tmp", "preview", "png")
      end

      # Temporary PDF file path
      def temp_pdf_path(filename)
        FileUtils.mkdir_p(temp_pdf_dir)
        temp_pdf_dir.join("#{filename}.pdf")
      end

      # Temporary PNG file path
      def temp_png_path(filename)
        FileUtils.mkdir_p(temp_png_dir)
        temp_png_dir.join("#{filename}.png")
      end

      module ClassMethods
        # Add any class-level methods here if needed
      end
    end
  end
end
