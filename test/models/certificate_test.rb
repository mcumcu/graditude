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

  test "requires presented_on when template minimum includes it" do
    certificate = Certificate.new(user: users(:one), graduate_name: "Johnny", honoree_name: "Mom & Dad", degree: "Bachelor of Science", presented_on: "")

    assert_not certificate.valid?
    assert_equal [ "can't be blank" ], certificate.errors[:presented_on]
  end

  test "rejects blank presented_on string on create" do
    certificate = Certificate.new(user: users(:one), graduate_name: "Johnny", honoree_name: "Mom & Dad", degree: "Bachelor of Science", presented_on: " ")

    assert_not certificate.valid?
    assert_equal [ "can't be blank" ], certificate.errors[:presented_on]
  end

  test "requires graduate name, honoree name, and degree on create" do
    certificate = Certificate.new(user: users(:one))

    assert_not certificate.valid?
    assert_includes certificate.errors[:graduate_name], "can't be blank"
    assert_includes certificate.errors[:honoree_name], "can't be blank"
    assert_includes certificate.errors[:degree], "can't be blank"
  end

  test "rejects blank degree on update" do
    certificate = certificates(:one)
    certificate.degree = ""

    assert_not certificate.valid?
    assert_includes certificate.errors[:degree], "can't be blank"
  end

  test "rejects a completely empty certificate on create" do
    certificate = Certificate.new(user: users(:one), graduate_name: "", honoree_name: "", degree: "", major: "", message: "", presented_on: "", nouns: [])

    assert_not certificate.valid?
    assert_includes certificate.errors[:graduate_name], "can't be blank"
    assert_includes certificate.errors[:honoree_name], "can't be blank"
    assert_includes certificate.errors[:degree], "can't be blank"
    assert_includes certificate.errors[:presented_on], "can't be blank"
  end

  test "allows blank message and nouns when required fields are present" do
    certificate = Certificate.new(user: users(:one), graduate_name: "Grad", honoree_name: "Honoree", degree: "Degree", presented_on: Date.today)

    assert certificate.valid?
  end
end
