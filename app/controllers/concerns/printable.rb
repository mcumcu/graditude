# frozen_string_literal: true

# Wrapper concern that includes the GraditudeFactory gem's Printable concern
# The gem handles all Prawn requirements and provides methods for generating certificates.
module Printable
  extend ActiveSupport::Concern

  included do
    include GraditudeFactory::Concerns::Printable
  end

  # Convenience aliases for backward compatibility
  def default_params
    default_certificate_params
  end

  # Legacy method: generates Penn certificate
  def make_document(params = {})
    pdf = generate_certificate_pdf(GraditudeFactory::Certificates::PennTemplate, params)
    pdf
  end

  # Legacy method: generates Westtown certificate PDF
  def make_westtown_document(params = {})
    pdf = generate_certificate_pdf(GraditudeFactory::Certificates::WesttownTemplate, params)
    pdf
  end

  # Legacy method: render PNG from Westtown certificate
  def rerender_png_path
    doc = make_westtown_document(@certificate&.data || default_params)
    pdf_path = temp_pdf_path(@certificate&.id || "_blank").to_s
    doc.render_file(pdf_path)

    png_path = temp_png_path(@certificate&.id || "_blank").to_s
    render_certificate_png(pdf_path, png_path)
  end
end
