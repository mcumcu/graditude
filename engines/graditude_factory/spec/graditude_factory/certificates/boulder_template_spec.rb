# frozen_string_literal: true

require "spec_helper"

RSpec.describe GraditudeFactory::Certificates::BoulderTemplate do
  let(:template) { GraditudeFactory::Certificates::BoulderTemplate.new }

  describe "#document_font" do
    it "returns path to old english font" do
      font = template.document_font
      expect(font).to include("oldenglishtextmt")
    end
  end

  describe "#body_font" do
    it "returns path to goudy font" do
      font = template.body_font
      expect(font).to include("GoudyTextMTStdRegularHYLT2")
    end
  end

  describe "#template_assets" do
    it "returns hash with required assets" do
      assets = template.template_assets
      expect(assets).to have_key(:banner)
      expect(assets).to have_key(:seal)
    end

    it "includes boulder.svg" do
      expect(template.template_assets[:banner]).to include("boulder.svg")
    end

    it "includes boulder-seal.png" do
      expect(template.template_assets[:seal]).to include("boulder-seal.png")
    end
  end

  describe "#generate" do
    let(:params) do
      {
        graduate_name: "Jane Doe",
        degree: "Bachelor of Science",
        major: "Computer Science",
        honoree_name: "University of Colorado Boulder",
        presented_on: "May 15, 2026",
        message: "Congratulations"
      }
    end

    let(:template_with_params) { GraditudeFactory::Certificates::BoulderTemplate.new(params) }

    it "generates a PDF document" do
      pdf = template_with_params.generate
      expect(pdf).to be_a(PrawnRails::Document)
    end

    it "renders without errors" do
      expect { template_with_params.generate }.not_to raise_error
    end
  end

  describe "#default_params" do
    it "starts with nil values for certificate fields" do
      expect(template.default_params[:graduate_name]).to be_nil
      expect(template.default_params[:degree]).to be_nil
      expect(template.default_params[:honoree_name]).to be_nil
    end
  end
end
