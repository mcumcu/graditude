require "test_helper"

class CertificateTest < ActiveSupport::TestCase
  test "normalizes presented_on strings before validation" do
    certificate = Certificate.new(user: users(:one), presented_on: "May 15, 2026")

    certificate.valid?

    assert_equal "2026-05-15", certificate.presented_on
  end

  test "rejects invalid presented_on values" do
    certificate = Certificate.new(user: users(:one), presented_on: "not a date")

    assert_not certificate.valid?
    assert_includes certificate.errors[:presented_on], "must be a valid date"
  end
end
