require "test_helper"

class CompareMythServiceTest < ActiveSupport::TestCase
  test "builds dedicated myth comparison payload" do
    fake_client = Object.new

    fake_client.define_singleton_method(:fetch_character) do |name|
      if name == "A"
        { character_idx: 1 }
      else
        { character_idx: 2 }
      end
    end

    fake_client.define_singleton_method(:fetch_myth) do |idx|
      if idx == 1
        {
          level: 47,
          max_level: 100,
          grade: 9,
          grade_name: "Michael",
          resurrection: 812,
          point: 993,
          max_point: 10000,
          score: 21479,
          total_score: 26479,
          stigma: { grade: 150, score: 5000, max_score: 5000, exp: 0 },
          grades: [
            { grade: 7, point: 19000, name: "Rafael", force: "Amp 10%", enabled: true },
            { grade: 9, point: 24500, name: "Michael", force: "Danos Críticos 25%", enabled: true },
            { grade: 10, point: 27500, name: "Metatron", force: "Amp 20%", enabled: false }
          ],
          lines: [
            [
              { name: "PVE Canc. Ig. Red Dano  +16", level: 5, score: 220, locked: false },
              { name: "PVP Ignorar Redução de Dano  +16", level: 5, score: 220, locked: false },
              { name: "Danos Críticos  +25", level: 5, score: 220, locked: false }
            ]
          ]
        }
      else
        {
          level: 40,
          max_level: 100,
          grade: 8,
          grade_name: "Uriel",
          resurrection: 700,
          point: 850,
          max_point: 10000,
          score: 19479,
          total_score: 24479,
          stigma: { grade: 130, score: 4300, max_score: 5000, exp: 20 },
          grades: [
            { grade: 9, point: 24500, name: "Michael", force: "Danos Críticos 25%", enabled: false }
          ],
          lines: [
            [
              { name: "PVE Canc. Ig. Red Dano  +8", level: 4, score: 180, locked: false },
              { name: "PVP Ignorar Redução de Dano  +8", level: 3, score: 150, locked: true },
              { name: "Danos Críticos  +15", level: 3, score: 150, locked: true }
            ]
          ]
        }
      end
    end

    service = CompareMythService.new(client: fake_client)
    payload = service.call(name_a: "A", name_b: "B")

    assert_equal true, payload[:comparison_ready]
    assert_equal 4, payload[:result][:summary_cards].size

    score_card = payload[:result][:summary_cards].find { |row| row[:metric] == :score }
    assert_equal 2000, score_card[:diff]

    assert_equal "Michael", payload[:result][:grade_summary][:grade_name_a]
    assert_equal "Uriel", payload[:result][:grade_summary][:grade_name_b]
    assert_equal 1, payload[:result][:grade_summary][:grade_diff]
    assert_equal "Metatron", payload[:result][:grade_summary][:next_grade_a][:name]
    assert payload[:result][:grade_summary][:estimated_score_to_next_a] > 0

    assert_equal 700, payload[:result][:stigma_summary][:score_diff]
    assert_equal :a, payload[:result][:line_summary][:winner]
    assert payload[:result][:line_node_rows].any?
    first_line_score = payload[:result][:line_node_rows].first
    assert first_line_score[:line_name].present?
    assert_not_nil first_line_score[:score_diff]

    first_attribute = payload[:result][:line_attribute_rows].first
    assert first_attribute[:attribute].present?
    assert_not_equal 0, first_attribute[:diff]

    status_row = payload[:result][:grade_rows].find { |row| row[:grade] == 9 }
    assert_equal :enabled_a_only, status_row[:status]

    highlighted = payload[:result][:line_attribute_rows].find { |row| row[:attribute] == "Danos Críticos" }
    assert_not_nil highlighted
    assert_equal true, highlighted[:is_special]
  end

  test "returns empty shape when one name is missing" do
    service = CompareMythService.new(client: ArmoryClient.new)
    payload = service.call(name_a: "A", name_b: nil)

    assert_equal false, payload[:comparison_ready]
    assert_equal [], payload[:result][:summary_cards]
    assert_equal [], payload[:result][:line_attribute_rows]
    assert_equal [], payload[:result][:grade_rows]
  end
end
