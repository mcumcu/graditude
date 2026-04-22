require "test_helper"

class PrintableTest < ActiveSupport::TestCase
  class PrintableDummy
    include Printable

    def make_penn_document(params = {})
      :penn
    end

    def make_westtown_document(params = {})
      :westtown
    end

    def make_boulder_document(params = {})
      :boulder
    end
  end

  test "make_certificate_document selects the correct document generator" do
    dummy = PrintableDummy.new

    assert_equal :penn, dummy.make_certificate_document("penn", {})
    assert_equal :westtown, dummy.make_certificate_document("westtown", {})
    assert_equal :boulder, dummy.make_certificate_document("boulder", {})
    assert_equal :boulder, dummy.make_certificate_document("unknown", {})
  end

  test "default_certificate_template falls back to env or boulder" do
    original_value = ENV["DEFAULT_CERTIFICATE_TEMPLATE"]
    ENV.delete("DEFAULT_CERTIFICATE_TEMPLATE")

    dummy = PrintableDummy.new
    assert_equal "boulder", dummy.default_certificate_template

    ENV["DEFAULT_CERTIFICATE_TEMPLATE"] = "penn"
    assert_equal "penn", dummy.default_certificate_template
  ensure
    if original_value.nil?
      ENV.delete("DEFAULT_CERTIFICATE_TEMPLATE")
    else
      ENV["DEFAULT_CERTIFICATE_TEMPLATE"] = original_value
    end
  end

  test "blank_certificate_png_path generates a blank PNG preview from the existing rendering pipeline" do
    dummy = PrintableDummy.new
    captured = {}

    fake_doc = Object.new
    fake_doc.define_singleton_method(:render_file) do |path|
      File.write(path, "PDF")
    end

    dummy.define_singleton_method(:make_certificate_document) do |template_name, params = {}|
      captured[:template] = template_name
      captured[:params] = params
      fake_doc
    end

    dummy.define_singleton_method(:render_certificate_png) do |pdf_path, png_path|
      captured[:pdf_path] = pdf_path
      captured[:png_path] = png_path
      png_path
    end

    result = dummy.blank_certificate_png_path("penn")

    assert_equal dummy.default_params, captured[:params]
    assert_equal "penn", captured[:template]
    assert_equal dummy.temp_pdf_path("_blank").to_s, captured[:pdf_path]
    assert_equal dummy.temp_png_path("_blank").to_s, captured[:png_path]
    assert_equal captured[:png_path], result
    assert_equal "PDF", File.read(captured[:pdf_path])
  ensure
    File.delete(dummy.temp_pdf_path("_blank")) if dummy&.temp_pdf_path("_blank")&.exist?
  end

  test "blank_certificate_png_path uses default template when no template is provided" do
    dummy = PrintableDummy.new
    captured = {}

    fake_doc = Object.new
    fake_doc.define_singleton_method(:render_file) do |path|
      File.write(path, "PDF")
    end

    dummy.define_singleton_method(:make_certificate_document) do |template_name, params = {}|
      captured[:template] = template_name
      captured[:params] = params
      fake_doc
    end

    dummy.define_singleton_method(:render_certificate_png) do |pdf_path, png_path|
      captured[:pdf_path] = pdf_path
      captured[:png_path] = png_path
      png_path
    end

    result = dummy.blank_certificate_png_path

    assert_equal dummy.default_params, captured[:params]
    assert_equal dummy.default_certificate_template, captured[:template]
    assert_equal dummy.temp_png_path("_blank").to_s, result
  ensure
    File.delete(dummy.temp_pdf_path("_blank")) if dummy&.temp_pdf_path("_blank")&.exist?
  end
end
