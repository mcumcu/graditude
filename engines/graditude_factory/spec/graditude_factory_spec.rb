# frozen_string_literal: true

require "spec_helper"

RSpec.describe GraditudeFactory do
  it "has a version number" do
    expect(GraditudeFactory::VERSION).not_to be nil
  end

  describe ".configure" do
    it "allows configuration of font_dir" do
      original_font_dir = GraditudeFactory.font_dir
      custom_path = "/custom/fonts"

      GraditudeFactory.configure do |config|
        config.font_dir = custom_path
      end

      expect(GraditudeFactory.font_dir).to eq(custom_path)

      # Reset
      GraditudeFactory.font_dir = original_font_dir
    end

    it "allows configuration of image_dir" do
      original_image_dir = GraditudeFactory.image_dir
      custom_path = "/custom/images"

      GraditudeFactory.configure do |config|
        config.image_dir = custom_path
      end

      expect(GraditudeFactory.image_dir).to eq(custom_path)

      # Reset
      GraditudeFactory.image_dir = original_image_dir
    end
  end

  describe "asset paths" do
    it "sets default font dir" do
      expect(GraditudeFactory::FONT_DIR).to match(/fonts$/)
    end

    it "sets default image dir" do
      expect(GraditudeFactory::IMG_DIR).to match(/images$/)
    end

    it "returns asset dir" do
      expect(GraditudeFactory::ASSET_DIR).to match(/assets$/)
    end
  end
end
