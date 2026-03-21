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
              { id: 1, name: "PVE Canc. Ig. Red Dano  +16", level: 5, score: 220, locked: false },
              { id: 5, name: "PVP Ignorar Redução de Dano  +16", level: 5, score: 220, locked: false },
              { id: 9, name: "Danos Críticos  +25", level: 5, score: 220, locked: false }
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
              { id: 1, name: "PVE Canc. Ig. Red Dano  +8", level: 4, score: 180, locked: false },
              { id: 5, name: "PVP Ignorar Redução de Dano  +8", level: 3, score: 150, locked: true },
              { id: 9, name: "Danos Críticos  +15", level: 3, score: 150, locked: true }
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
    assert_equal 34.03, payload[:result][:grade_summary][:progress_missing_a]
    assert payload[:result][:grade_summary][:estimated_score_to_next_a] > 0

    assert_equal 700, payload[:result][:stigma_summary][:score_diff]
    assert_equal :a, payload[:result][:line_summary][:winner]
    assert payload[:result][:line_id_rows].any?
    row_id_1 = payload[:result][:line_id_rows].find { |row| row[:id] == 1 }
    assert_not_nil row_id_1
    assert_equal 220, row_id_1[:points_a]
    assert_equal 180, row_id_1[:points_b]
    assert_equal 40, row_id_1[:diff]
    assert_equal 1, row_id_1[:position_a]
    assert_equal 1, row_id_1[:position_b]

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

  test "parses formatted score strings when computing points to next grade" do
    fake_client = Object.new

    fake_client.define_singleton_method(:fetch_character) do |_name|
      { character_idx: 1 }
    end

    fake_client.define_singleton_method(:fetch_myth) do |_idx|
      ArmoryMythNormalizer.call(
        {
          "grade" => 9,
          "gradeName" => "Michael",
          "point" => "26,500",
          "maxPoint" => "30,000",
          "score" => "21,000",
          "totalScore" => "26,500",
          "grades" => [
            { "grade" => 9, "point" => "24,500", "name" => "Michael", "enabled" => true },
            { "grade" => 10, "point" => "27,500", "name" => "Metatron", "enabled" => false }
          ],
          "stigma" => { "grade" => "100", "score" => "3000", "maxScore" => "5000", "exp" => "0" },
          "lines" => []
        }
      )
    end

    payload = CompareMythService.new(client: fake_client).call(name_a: "A", name_b: "B")
    grade_summary = payload.dig(:result, :grade_summary)

    assert_equal 1000, grade_summary.dig(:next_grade_a, :remaining_points)
    assert_equal 33.33, grade_summary[:progress_missing_a]
  end

  test "uses first disabled grade and totalScore when point is partial" do
    fake_client = Object.new

    fake_client.define_singleton_method(:fetch_character) do |name|
      { character_idx: name == "A" ? 1 : 2 }
    end

    fake_client.define_singleton_method(:fetch_myth) do |idx|
      if idx == 1
        ArmoryMythNormalizer.call(
          {
            "grade" => 9,
            "gradeName" => "Michael",
            "point" => "2",
            "totalPoint" => "26,500",
            "maxPoint" => "30,000",
            "score" => "21,000",
            "totalScore" => "26,500",
            "grades" => [
              { "grade" => 9, "point" => "24,500", "name" => "Michael", "enabled" => true },
              { "grade" => 10, "point" => "27,500", "name" => "Metatron", "enabled" => false },
              { "grade" => 11, "point" => "31,000", "name" => "Noxariel", "enabled" => false }
            ],
            "stigma" => { "grade" => "100", "score" => "3000", "maxScore" => "5000", "exp" => "0" },
            "lines" => []
          }
        )
      else
        ArmoryMythNormalizer.call(
          {
            "grade" => 10,
            "gradeName" => "Metatron",
            "point" => "8",
            "totalPoint" => "30,000",
            "maxPoint" => "35,000",
            "score" => "22,000",
            "totalScore" => "30,100",
            "grades" => [
              { "grade" => 10, "point" => "27,500", "name" => "Metatron", "enabled" => true },
              { "grade" => 11, "point" => "31,000", "name" => "Noxariel", "enabled" => false }
            ],
            "stigma" => { "grade" => "100", "score" => "3000", "maxScore" => "5000", "exp" => "0" },
            "lines" => []
          }
        )
      end
    end

    payload = CompareMythService.new(client: fake_client).call(name_a: "A", name_b: "B")
    grade_summary = payload.dig(:result, :grade_summary)

    assert_equal 1000, grade_summary.dig(:next_grade_a, :remaining_points)
    assert_equal 900, grade_summary.dig(:next_grade_b, :remaining_points)
    assert_equal "Metatron", grade_summary.dig(:next_grade_a, :name)
    assert_equal 33.33, grade_summary[:progress_missing_a]
    assert_equal 25.71, grade_summary[:progress_missing_b]
  end
end
