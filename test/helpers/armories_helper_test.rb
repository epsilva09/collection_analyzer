require "test_helper"

class ArmoriesHelperTest < ActionView::TestCase
  test "materials_filter_options returns unique sorted materials and buckets" do
    sections = [
      {
        key: :near,
        label: "Near",
        items: [
          { name: "Core Alpha", total_needed: 3 },
          { name: "Core Beta", total_needed: 2 }
        ]
      },
      {
        key: :low,
        label: "Low",
        items: [
          { name: "Core Beta", total_needed: 4 },
          { name: "Core Gamma", total_needed: 1 }
        ]
      }
    ]

    options = materials_filter_options(sections)

    assert_equal [ "Core Alpha", "Core Beta", "Core Gamma" ], options[:materials]
    assert_equal [ "Low", "Near" ], options[:buckets]
  end

  test "material_collections_filter_options returns unique sorted names and bucket labels" do
    collections = [
      { tier: "Tier 1", collection_name: "Lago", bucket: :low },
      { tier: "Tier 2", collection_name: "Castelo", bucket: :near },
      { tier: "Tier 1", collection_name: "Lago", bucket: :low }
    ]

    options = material_collections_filter_options(collections)

    assert_equal [ "Tier 1 Lago", "Tier 2 Castelo" ], options[:collections]
    assert_equal [ t("armories.progress.labels.low"), t("armories.progress.labels.near") ].sort_by(&:downcase), options[:buckets]
  end

  test "progress_important_attributes is unique and normalized" do
    values = progress_important_attributes

    assert values.present?
    assert_equal values.uniq, values
    assert values.none?(&:blank?)
  end

  test "progress_material_filter_values uses precomputed aggregated materials when available" do
    entry = {
      materials: [
        { name: "Ignored", needed: 99 }
      ],
      aggregated_materials: [
        { name: "Ticket Especial", needed: 3 },
        { name: "Core", needed: 1 }
      ]
    }

    assert_equal [ "Ticket Especial", "Core" ], progress_material_filter_values(entry)
  end
end
