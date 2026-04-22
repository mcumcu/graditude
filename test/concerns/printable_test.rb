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
end
