require "test_helper"

class CatalogNormalizerTest < ActiveSupport::TestCase
  test "list_from_text handles arrays and strings" do
    assert_equal [ "a", "b" ], Catalog::Normalizer.list_from_text([ "a", "b", " " ])
    assert_equal [ "one", "two" ], Catalog::Normalizer.list_from_text("one, two")
    assert_equal [ "one", "two" ], Catalog::Normalizer.list_from_text("one\n\ntwo")
  end

  test "list_from_lines preserves commas" do
    input = "Customize the graduate name, honoree, degree\nSecond bullet"

    assert_equal [ "Customize the graduate name, honoree, degree", "Second bullet" ],
      Catalog::Normalizer.list_from_lines(input)
  end

  test "hashify stringifies keys" do
    input = { name: "Catalog", metadata: { certificate_templates: "boulder" } }

    output = Catalog::Normalizer.hashify(input)

    assert_equal "Catalog", output["name"]
    assert_equal "boulder", output.dig("metadata", "certificate_templates")
  end

  test "marketing_features_from_text parses name and description" do
    features = Catalog::Normalizer.marketing_features_from_text(
      "Premium print | Crisp layout\nReliable delivery - Fast shipping\nThoughtful gifting"
    )

    assert_equal [
      { "name" => "Premium print", "description" => "Crisp layout" },
      { "name" => "Reliable delivery", "description" => "Fast shipping" },
      { "name" => "Thoughtful gifting" }
    ], features
  end

  test "variant_format uses metadata and inference" do
    assert_equal "framed", Catalog::Normalizer.variant_format(
      metadata: { "format" => "framed" },
      heading: "",
      description: "",
      infer: true
    )

    assert_equal "unframed", Catalog::Normalizer.variant_format(
      metadata: { "format" => "print" },
      heading: "",
      description: "",
      infer: true
    )

    assert_equal "unframed", Catalog::Normalizer.variant_format(
      metadata: {},
      heading: "Unframed certificate",
      description: nil,
      infer: true
    )

    assert_equal "unframed", Catalog::Normalizer.variant_format(
      metadata: {},
      heading: "Printed certificate of gratitude",
      description: nil,
      infer: true
    )

    assert_nil Catalog::Normalizer.variant_format(
      metadata: {},
      heading: "Unframed certificate",
      description: nil,
      infer: false
    )
  end
end
