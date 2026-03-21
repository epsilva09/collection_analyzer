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

    service = CompareOverviewService.new(client: fake_client)
    payload = service.call(name_a: "A", name_b: "B")

    assert_equal true, payload[:comparison_ready]
    assert_equal "A", payload[:result][:name_a]
    assert_equal "B", payload[:result][:name_b]
    assert_equal CompareOverviewService::CARD_METRICS.size, payload[:result][:comparison_cards].size
    assert_equal 4, payload[:result][:progression_gaps].size

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
  end
end
