# frozen_string_literal: true

# Wrapper concern that includes the GraditudeFactory gem's Printable concern
# The gem handles all Prawn requirements and provides methods for generating certificates.
module Printable
  extend ActiveSupport::Concern

  included do
    include GraditudeFactory::Concerns::Printable

    ASSET_DIR = "app/assets" unless defined?(ASSET_DIR)
    FONT_DIR = "#{ASSET_DIR}/fonts" unless defined?(FONT_DIR)
    IMG_DIR = "#{ASSET_DIR}/images" unless defined?(IMG_DIR)
  end

  # Convenience aliases for backward compatibility
  def default_params
    default_certificate_params
  end

  # Legacy method: generates Penn certificate
  def make_penn_document(params = {})
    pdf = generate_certificate_pdf(GraditudeFactory::Certificates::PennTemplate, params)
    pdf
  end

  # Legacy method: generates Westtown certificate PDF
  def make_westtown_document(params = {})
    pdf = generate_certificate_pdf(GraditudeFactory::Certificates::WesttownTemplate, params)
    pdf
  end

  # Legacy method: generates UC Boulder certificate PDF
  def make_boulder_document(params = {})
    pdf = generate_certificate_pdf(GraditudeFactory::Certificates::BoulderTemplate, params)
    pdf
  end

  # Legacy method: render PNG from the certificate template
  def rerender_png_path
    template_name = @certificate&.template.presence || default_certificate_template
    params = @certificate&.data || default_params
    doc = make_certificate_document(template_name, params)

    pdf_path = temp_pdf_path(@certificate&.id || "_blank").to_s
    doc.render_file(pdf_path)

    png_path = temp_png_path(@certificate&.id || "_blank").to_s
    render_certificate_png(pdf_path, png_path)
  end

  def make_certificate_document(template_name, params = {})
    case template_name.to_s
    when "penn"
      make_penn_document(params)
    when "westtown"
      make_westtown_document(params)
    else
      make_boulder_document(params)
    end
  end

  def default_certificate_template
    ENV.fetch("DEFAULT_CERTIFICATE_TEMPLATE", "boulder")
  end
end
