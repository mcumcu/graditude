# frozen_string_literal: true

require "spec_helper"

RSpec.describe GraditudeFactory::Certificates::WesttownTemplate do
  let(:template) { GraditudeFactory::Certificates::WesttownTemplate.new }

  describe "#page_config" do
    it "returns custom westtown page size" do
      config = template.page_config
      expect(config[:page_size]).to eq([175.mm, 227.mm])
      expect(config[:page_layout]).to eq(:landscape)
      expect(config[:margin]).to eq([0, 0, 0, 0])
    end
  end

  describe "#document_font" do
    it "returns path to jost font" do
      font = template.document_font
      expect(font).to include("Jost")
    end
  end

  describe "#name_font" do
    it "returns path to literata font" do
      font = template.name_font
      expect(font).to include("Literata")
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
      expect(assets).to have_key(:banner)
      expect(assets).to have_key(:seal)
    end

    it "includes westtown.svg" do
      expect(template.template_assets[:banner]).to include("westtown.svg")
    end

    it "includes westtown seal" do
      seal = template.template_assets[:seal]
      expect(seal).to match(/westtown_seal/)
    end
  end
end
