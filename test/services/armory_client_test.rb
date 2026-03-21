require "test_helper"
require "json"
require "ostruct"

class ArmoryClientTest < ActiveSupport::TestCase
  test "fetch_character returns normalized character payload" do
    fake = Object.new
    def fake.get(*_args)
      OpenStruct.new(body: {
        character: {
          characterIdx: 99,
          name: "Cadamantis",
          level: 200,
          atackPowerPVE: 1000,
          defensePowerPVE: 900
        }
      }.to_json)
    end

    client = ArmoryClient.new(fake)
    character = client.fetch_character("Cadamantis")

    assert_equal 99, character[:character_idx]
    assert_equal "Cadamantis", character[:name]
    assert_equal 200, character[:level]
    assert_equal 1000, character[:attack_power_pve]
    assert_equal 900, character[:defense_power_pve]
  end

  test "fetch_character handles missing character block" do
    fake = Object.new
    def fake.get(*_args)
      OpenStruct.new(body: {}.to_json)
    end

    client = ArmoryClient.new(fake)
    character = client.fetch_character("Unknown")

    assert_equal 0, character[:character_idx]
    assert_equal "", character[:name]
  end

  test "fetch_myth returns normalized payload" do
    fake = Object.new
    def fake.get(*_args)
      OpenStruct.new(body: {
        level: 84,
        maxLevel: 100,
        grade: 9,
        gradeName: "Michael",
        values: [ "HP +100" ],
        stigma: { score: 10, maxScore: 20 }
      }.to_json)
    end

    client = ArmoryClient.new(fake)
    myth = client.fetch_myth(123)

    assert_equal 84, myth[:level]
    assert_equal 100, myth[:max_level]
    assert_equal 9, myth[:grade]
    assert_equal "Michael", myth[:grade_name]
    assert_equal [ "HP +100" ], myth[:values]
    assert_equal 10, myth[:stigma][:score]
    assert_equal 20, myth[:stigma][:max_score]
  end

  test "fetch_force_wing returns normalized payload" do
    fake = Object.new
    def fake.get(*_args)
      OpenStruct.new(body: {
        grade: 4,
        level: 400,
        gradeName: "Epico",
        gradeData: [
          { name: "Asa Arcana", grade: 3, gradeName: "3", forces: [ { name: "ATK +20" } ] }
        ],
        status: [ "HP +10" ],
        buffValue: [ "ATK +30" ]
      }.to_json)
    end

    client = ArmoryClient.new(fake)
    wing = client.fetch_force_wing(123)

    assert_equal 4, wing[:grade]
    assert_equal 400, wing[:level]
    assert_equal "Epico", wing[:grade_name]
    assert_equal [ "ATK +20" ], wing[:grade_data].first[:forces]
    assert_equal [ "HP +10" ], wing[:status]
    assert_equal [ "ATK +30" ], wing[:buff_value]
  end

  test "fetch_honor_medal returns normalized payload" do
    fake = Object.new
    def fake.get(*_args)
      OpenStruct.new(body: {
        currentGrade: 5,
        currentGradeName: "Lenda",
        level: 10,
        percent: 100,
        grades: [
          {
            grade: 1,
            name: "Capitao",
            slots: [
              { id: 0, level: 10, maxLevel: 10, description: "HP +10", opened: true, forceId: 1, forceValue: 10 }
            ]
          }
        ],
        values: [ "HP +10" ]
      }.to_json)
    end

    client = ArmoryClient.new(fake)
    medal = client.fetch_honor_medal(123)

    assert_equal 5, medal[:current_grade]
    assert_equal "Lenda", medal[:current_grade_name]
    assert_equal 10, medal[:level]
    assert_equal 100, medal[:percent]
    assert_equal 1, medal[:grades].first[:grade]
    assert_equal true, medal[:grades].first[:slots].first[:opened]
    assert_equal [ "HP +10" ], medal[:values]
  end

  test "fetch_stellar returns normalized payload" do
    fake = Object.new
    def fake.get(*_args)
      OpenStruct.new(body: {
        values: [ "PVE Perfuracao +8" ],
        lines: [
          {
            line: 1,
            level: 5,
            setValues: [ "ATK +10" ],
            data: [
              { name: "PVE Perfuracao +8", force: 1, value: 8, level: 5, line: 1 }
            ]
          }
        ]
      }.to_json)
    end

    client = ArmoryClient.new(fake)
    stellar = client.fetch_stellar(123)

    assert_equal [ "PVE Perfuracao +8" ], stellar[:values]
    assert_equal 1, stellar[:lines].first[:line]
    assert_equal [ "ATK +10" ], stellar[:lines].first[:set_values]
    assert_equal "PVE Perfuracao +8", stellar[:lines].first[:data].first[:name]
  end

  test "fetch_ability returns normalized payload" do
    fake = Object.new
    def fake.get(*_args)
      OpenStruct.new(body: {
        passive: [ { name: "HP", level: 10, force: "HP +100", target: nil } ],
        blended: [ { name: "Cura I", level: 0, force: "Cura +100", target: "Jogador" } ],
        karma: [ { name: "PVE Todos os Ataques", level: 13, force: "PVE Todos os Ataques +39" } ]
      }.to_json)
    end

    client = ArmoryClient.new(fake)
    ability = client.fetch_ability(123)

    assert_equal "HP", ability[:passive].first[:name]
    assert_equal 10, ability[:passive].first[:level]
    assert_equal "Jogador", ability[:blended].first[:target]
    assert_equal "PVE Todos os Ataques", ability[:karma].first[:name]
  end

  test "new endpoints reuse cache for same key" do
    cache = ActiveSupport::Cache::MemoryStore.new
    calls = 0

    fake = Object.new
    fake.define_singleton_method(:get) do |*_args|
      calls += 1
      OpenStruct.new(body: ({ values: [] }.to_json))
    end

    client = ArmoryClient.new(fake, cache: cache, cache_ttl: 10.minutes)
    client.fetch_stellar(999)
    client.fetch_stellar(999)

    assert_equal 1, calls
  end

  test "new endpoint normalizers handle malformed payload blocks" do
    fake = Object.new
    def fake.get(*_args)
      OpenStruct.new(body: {
        grades: "invalid",
        lines: [ "invalid", { line: 2, data: [ "x" ] } ],
        passive: [ "x", { name: "HP", level: "10" } ]
      }.to_json)
    end

    client = ArmoryClient.new(fake)

    myth = client.fetch_myth(111)
    stellar = client.fetch_stellar(111)
    ability = client.fetch_ability(111)

    assert_equal [], myth[:grades]
    assert_equal 1, stellar[:lines].size
    assert_equal 1, ability[:passive].size
    assert_equal "HP", ability[:passive].first[:name]
  end

  test "fetch_collection_details reuses cached response" do
    cache = ActiveSupport::Cache::MemoryStore.new
    calls = 0

    fake = Object.new
    fake.define_singleton_method(:get) do |*_args|
      calls += 1
      OpenStruct.new(body: ({ values: [ "A" ], data: [] }.to_json))
    end

    client = ArmoryClient.new(fake, cache: cache, cache_ttl: 10.minutes)
    first = client.fetch_collection_details(888)
    second = client.fetch_collection_details(888)

    assert_equal 1, calls
    assert_equal first, second
  end

  test "raises friendly error when JSON is invalid" do
    fake = Object.new
    fake.define_singleton_method(:get) do |*_args|
      OpenStruct.new(body: "{invalid-json")
    end

    client = ArmoryClient.new(fake)

    error = assert_raises(RuntimeError) do
      client.fetch_character_idx("Name")
    end

    assert_match(/Invalid JSON response:/, error.message)
  end

  test "fetch_character_idx returns id when API responds" do
    fake = Object.new
    def fake.get(*)
      OpenStruct.new(body: { character: { characterIdx: 12345 } }.to_json)
    end

    client = ArmoryClient.new(fake)
    assert_equal 12345, client.fetch_character_idx("Name")
  end

  test "fetch_collection returns values array" do
    fake = Object.new
    def fake.get(*)
      OpenStruct.new(body: ({ values: [ "HP +10", "STR +5" ] }.to_json))
    end

    client = ArmoryClient.new(fake)
    assert_equal [ "HP +10", "STR +5" ], client.fetch_collection(123)
  end

  test "fetch_collection_details returns both values and data" do
    fake = Object.new
    def fake.get(*)
      OpenStruct.new(body: ({ values: [ "A" ], data: [ { "foo" => "bar" } ] }.to_json))
    end

    client = ArmoryClient.new(fake)
    expect = { values: [ "A" ], data: [ { "foo" => "bar" } ] }
    assert_equal expect, client.fetch_collection_details(321)
  end

  test "fetch_honor_medal uses configured medal type in route" do
    urls = []
    fake = Object.new
    fake.define_singleton_method(:get) do |url, *_args|
      urls << url
      OpenStruct.new(body: ({ values: [] }.to_json))
    end

    client = ArmoryClient.new(fake)
    client.fetch_honor_medal(777, medal_type: 3)

    assert_match(%r{/api/website/armory/honor-medal/3/777$}, urls.first)
  end
end
