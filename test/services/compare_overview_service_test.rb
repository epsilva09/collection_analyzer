require "test_helper"

class CompareOverviewServiceTest < ActiveSupport::TestCase
  test "returns overview cards and progression gaps for both characters" do
    fake_client = Object.new

    fake_client.define_singleton_method(:fetch_character) do |name|
      if name == "A"
        {
          character_idx: 1,
          level: 200,
          attack_power_pve: 1200,
          defense_power_pve: 900,
          attack_power_pvp: 1100,
          defense_power_pvp: 880,
          myth_score: 26000,
          achievement_point: 12000
        }
      else
        {
          character_idx: 2,
          level: 190,
          attack_power_pve: 1100,
          defense_power_pve: 850,
          attack_power_pvp: 1000,
          defense_power_pvp: 830,
          myth_score: 23000,
          achievement_point: 10000
        }
      end
    end

    fake_client.define_singleton_method(:fetch_myth) do |idx|
      idx == 1 ? { level: 80, max_level: 100, grade_name: "Michael" } : { level: 70, max_level: 100, grade_name: "Uriel" }
    end
    fake_client.define_singleton_method(:fetch_force_wing) do |idx|
      idx == 1 ? { level: 400, grade_name: "Epico" } : { level: 350, grade_name: "Raro" }
    end
    fake_client.define_singleton_method(:fetch_honor_medal) do |idx|
      idx == 1 ? { percent: 100, current_grade_name: "Lenda" } : { percent: 80, current_grade_name: "Heroi" }
    end
    fake_client.define_singleton_method(:fetch_stellar) do |idx|
      idx == 1 ? { lines: [ { level: 5 }, { level: 5 } ], values: [ "ATK" ] } : { lines: [ { level: 4 }, { level: 3 } ], values: [] }
    end
    fake_client.define_singleton_method(:fetch_collection_details) do |idx|
      if idx == 1
        {
          values: [ "ATK +20" ],
          data: [
            {
              "name" => "Mundo",
              "collections" => [
                {
                  "name" => "Elo Perdido I",
                  "progress" => 100,
                  "rewards" => [
                    { "description" => "ATK +10", "applied" => true },
                    { "description" => "ATK +20", "applied" => true }
                  ]
                },
                {
                  "name" => "Elo Perdido II",
                  "progress" => 85,
                  "rewards" => [
                    { "description" => "ATK +5", "applied" => true },
                    { "description" => "ATK +10", "applied" => false }
                  ]
                }
              ]
            }
          ]
        }
      else
        {
          values: [ "ATK +5" ],
          data: [
            {
              "name" => "Mundo",
              "collections" => [
                {
                  "name" => "Elo Perdido I",
                  "progress" => 60,
                  "rewards" => [
                    { "description" => "ATK +10", "applied" => true },
                    { "description" => "ATK +20", "applied" => false }
                  ]
                },
                {
                  "name" => "Elo Perdido II",
                  "progress" => 40,
                  "rewards" => [
                    { "description" => "ATK +5", "applied" => true },
                    { "description" => "ATK +10", "applied" => false }
                  ]
                }
              ]
            }
          ]
        }
      end
    end

    service = CompareOverviewService.new(client: fake_client)
    payload = service.call(name_a: "A", name_b: "B", weight_profile: "raid")

    assert_equal true, payload[:comparison_ready]
    assert_equal "A", payload[:result][:name_a]
    assert_equal "B", payload[:result][:name_b]
    assert_equal :raid, payload[:result][:weight_profile]
    assert_equal CompareOverviewService::CARD_METRICS.size, payload[:result][:comparison_cards].size
    assert_equal 4, payload[:result][:progression_gaps].size
    assert_equal 2, payload[:result][:collection_macro][:a][:total]
    assert_equal 1, payload[:result][:collection_macro][:a][:completed]
    assert_equal 1, payload[:result][:collection_macro][:a][:near_completion]
    assert_equal 42.5, payload[:result][:collection_macro][:average_progress_diff]
    assert_equal 1, payload[:result][:collection_macro][:unlocked_reward_diff]
    assert payload[:result][:weighted_profiles][:pve][:score_a] > payload[:result][:weighted_profiles][:pve][:score_b]
    assert payload[:result][:weighted_profiles][:pvp][:score_a] > payload[:result][:weighted_profiles][:pvp][:score_b]
    assert payload[:result][:weighted_profiles][:overall][:score_a] > payload[:result][:weighted_profiles][:overall][:score_b]
    assert_equal :a, payload[:result][:weighted_profiles][:overall][:winner]
    assert_equal 5, payload[:result][:weighted_profiles][:pve][:contributions].size
    assert_equal 0.42, payload[:result][:weighted_profiles][:pve][:contributions].first[:weight]

    level_card = payload[:result][:comparison_cards].find { |row| row[:metric] == :level }
    assert_equal 10, level_card[:diff]

    myth_gap = payload[:result][:progression_gaps].find { |row| row[:system] == :myth }
    assert_equal 10.0, myth_gap[:diff]
  end

  test "returns empty shape when one name is missing" do
    service = CompareOverviewService.new(client: ArmoryClient.new)
    payload = service.call(name_a: "A", name_b: nil)

    assert_equal false, payload[:comparison_ready]
    assert_equal [], payload[:result][:comparison_cards]
    assert_equal [], payload[:result][:progression_gaps]
    assert_equal({}, payload[:result][:weighted_profiles])
    assert_equal({}, payload[:result][:collection_macro])
  end

  test "falls back to balanced profile when preset is invalid" do
    fake_client = Object.new
    fake_client.define_singleton_method(:fetch_character) do |_name|
      {
        character_idx: 0,
        level: 0,
        attack_power_pve: 0,
        defense_power_pve: 0,
        attack_power_pvp: 0,
        defense_power_pvp: 0,
        myth_score: 0,
        achievement_point: 0
      }
    end

    service = CompareOverviewService.new(client: fake_client)
    payload = service.call(name_a: "A", name_b: "B", weight_profile: "unknown")

    assert_equal :balanced, payload[:result][:weight_profile]
  end
end
