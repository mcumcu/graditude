# frozen_string_literal: true

require "spec_helper"

RSpec.describe GraditudeFactory::Certificates::Template do
  let(:template) { GraditudeFactory::Certificates::Template.new }

  describe "#initialize" do
    it "initializes with default params" do
      expect(template.params).to include(:graduate_name, :degree)
    end

    it "merges passed params with defaults" do
      params = { graduate_name: "John Doe" }
      template = GraditudeFactory::Certificates::Template.new(params)
      expect(template.params[:graduate_name]).to eq("John Doe")
    end
  end

  describe "#default_params" do
    it "returns a hash with necessary keys" do
      params = template.default_params
      expect(params).to have_key(:graduate_name)
      expect(params).to have_key(:degree)
      expect(params).to have_key(:major)
      expect(params).to have_key(:nouns)
      expect(params).to have_key(:honoree_name)
      expect(params).to have_key(:message)
      expect(params).to have_key(:presented_on)
    end
  end

  describe "#width" do
    it "raises error if pdf not created" do
      expect { template.width }.to raise_error(NoMethodError)
    end
  end

  describe "helper methods" do
    let(:template_with_pdf) do
      t = GraditudeFactory::Certificates::Template.new
      allow(t).to receive(:@pdf).and_return(double(bounds: double(width: 200.mm)))
      t
    end

    it "calculates half_width" do
      allow(template_with_pdf).to receive(:width).and_return(200.mm)
      expect(template_with_pdf.half_width).to eq(100.mm)
    end

    it "returns margin_horizontal" do
      expect(template.margin_horizontal).to eq(30.mm)
    end

    it "returns signature_width" do
      expect(template.signature_width).to eq(70.mm)
    end
  end
end
