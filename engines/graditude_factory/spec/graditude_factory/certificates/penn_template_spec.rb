# frozen_string_literal: true

require "spec_helper"

RSpec.describe GraditudeFactory::Certificates::PennTemplate do
  let(:template) { GraditudeFactory::Certificates::PennTemplate.new }

  describe "#page_config" do
    it "returns letter landscape page config" do
      config = template.page_config
      expect(config[:page_size]).to eq("LETTER")
      expect(config[:page_layout]).to eq(:landscape)
      expect(config[:margin]).to eq([0, 0, 0, 0])
    end
  end

  describe "#document_font" do
    it "returns path to engraver font" do
      font = template.document_font
      expect(font).to include("OPTIEngraversOldEnglish")
    end
  end

  describe "#signature_font" do
    it "returns path to signature font" do
      font = template.signature_font
      expect(font).to include("HomemadeApple")
    end
  end

  describe "#template_assets" do
    it "returns hash with required assets" do
      assets = template.template_assets
      expect(assets).to have_key(:background)
      expect(assets).to have_key(:banner)
      expect(assets).to have_key(:seal)
    end

    it "includes penn.svg" do
      expect(template.template_assets[:banner]).to include("penn.svg")
    end

    it "includes penn_seal.png" do
      expect(template.template_assets[:seal]).to include("penn_seal.png")
    end
  end

  describe "#default_params" do
    it "starts with nil values" do
      expect(template.default_params[:graduate_name]).to be_nil
    end
  end
end
