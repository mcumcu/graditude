# frozen_string_literal: true

require "spec_helper"

RSpec.describe GraditudeFactory::Concerns::Printable do
  let(:controller_class) do
    Class.new do
      include GraditudeFactory::Concerns::Printable
    end
  end

  let(:controller) { controller_class.new }

  describe "#default_certificate_params" do
    it "returns default params hash" do
      params = controller.default_certificate_params
      expect(params).to have_key(:graduate_name)
      expect(params).to have_key(:degree)
      expect(params).to be_a(Hash)
    end
  end

  describe "#temp_pdf_dir" do
    it "returns a path ending with tmp/preview/pdf" do
      dir = controller.temp_pdf_dir.to_s
      expect(dir).to match(%r{tmp/preview/pdf})
    end
  end

  describe "#temp_png_dir" do
    it "returns a path ending with tmp/preview/png" do
      dir = controller.temp_png_dir.to_s
      expect(dir).to match(%r{tmp/preview/png})
    end
  end

  describe "#temp_pdf_path" do
    it "returns a path with .pdf extension" do
      path = controller.temp_pdf_path("test").to_s
      expect(path).to end_with(".pdf")
    end

    it "includes the filename" do
      path = controller.temp_pdf_path("myfile").to_s
      expect(path).to include("myfile")
    end
  end

  describe "#temp_png_path" do
    it "returns a path with .png extension" do
      path = controller.temp_png_path("test").to_s
      expect(path).to end_with(".png")
    end

    it "includes the filename" do
      path = controller.temp_png_path("myfile").to_s
      expect(path).to include("myfile")
    end
  end
end
