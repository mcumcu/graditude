require "test_helper"

class CatalogContractTest < ActiveSupport::TestCase
  test "from_stripe applies defaults when fields are missing" do
    data = Catalog::Contract.from_stripe(product: {}, price: {}, with_defaults: true)

    assert_equal Product::DEFAULT_HEADING, data[:heading]
    assert_equal Product::DEFAULT_EYEBROW, data[:eyebrow]
    assert_equal Product::DEFAULT_DESCRIPTION_PARAGRAPHS, data[:description_paragraphs]
    assert_equal Product::DEFAULT_DESCRIPTION_PARAGRAPHS.first, data[:short_description]
    assert_equal Product::DEFAULT_DETAIL_INTRO, data[:detail_intro]
    assert_equal Product::DEFAULT_MARKETING_FEATURES, data[:marketing_features]
  end

  test "from_input normalizes list fields" do
    data = Catalog::Contract.from_input(
      heading: "Catalog Heading",
      description: "First paragraph.\n\nSecond paragraph.",
      attributes: "Archival paper\nPremium finish",
      marketing_features: "Premium print | Crisp layout\nReliable delivery",
      certificate_templates: "boulder, westtown",
      images: "https://example.com/a.png\nhttps://example.com/b.png",
      active: "1"
    )

    assert_equal [ "First paragraph.", "Second paragraph." ], data[:description_paragraphs]
    assert_equal [ "Archival paper", "Premium finish" ], data[:attributes]
    assert_equal [ "boulder", "westtown" ], data[:certificate_templates]
    assert_equal [ "https://example.com/a.png", "https://example.com/b.png" ], data[:images]
    assert_equal true, data[:active]
  end
end
