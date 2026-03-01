require "test_helper"

class CollectionSnapshotServiceTest < ActiveSupport::TestCase
  test "reuses cached snapshot for repeated requests" do
    cache = ActiveSupport::Cache::MemoryStore.new

    fetch_idx_calls = 0
    fetch_details_calls = 0

    fake_client = Object.new
    fake_client.define_singleton_method(:fetch_character_idx) do |_name|
      fetch_idx_calls += 1
      999
    end

    fake_client.define_singleton_method(:fetch_collection_details) do |_idx|
      fetch_details_calls += 1
      {
        values: [],
        data: [
          {
            "name" => "Tier 1",
            "collections" => [
              { "name" => "Any", "progress" => 10, "rewards" => [ { "description" => "HP +1" } ] }
            ]
          }
        ]
      }
    end

    service = CollectionSnapshotService.new(client: fake_client, cache: cache, cache_ttl: 10.minutes)

    first = service.call("Cadamantis")
    second = service.call("Cadamantis")

    assert_equal 1, fetch_idx_calls
    assert_equal 1, fetch_details_calls
    assert_equal first, second
  end

  test "cache is scoped by locale" do
    cache = ActiveSupport::Cache::MemoryStore.new
    fetch_idx_calls = 0

    fake_client = Object.new
    fake_client.define_singleton_method(:fetch_character_idx) do |_name|
      fetch_idx_calls += 1
      777
    end

    fake_client.define_singleton_method(:fetch_collection_details) do |_idx|
      {
        values: [],
        data: [
          {
            "name" => "Tier 1",
            "collections" => [
              { "name" => "Any", "progress" => 10, "rewards" => [ { "description" => "HP +1" } ] }
            ]
          }
        ]
      }
    end

    service = CollectionSnapshotService.new(client: fake_client, cache: cache, cache_ttl: 10.minutes)

    service.call("Cadamantis", locale: "pt-BR")
    service.call("Cadamantis", locale: "pt-BR")
    service.call("Cadamantis", locale: "en")

    assert_equal 2, fetch_idx_calls
  end

  test "cached snapshot is not mutated across calls" do
    cache = ActiveSupport::Cache::MemoryStore.new

    fake_client = Object.new
    fake_client.define_singleton_method(:fetch_character_idx) { |_name| 321 }
    fake_client.define_singleton_method(:fetch_collection_details) do |_idx|
      {
        values: [],
        data: [
          {
            "name" => "Tier 1",
            "collections" => [
              { "name" => "Any", "progress" => 10, "rewards" => [ { "description" => "HP +1" } ] }
            ]
          }
        ]
      }
    end

    service = CollectionSnapshotService.new(client: fake_client, cache: cache, cache_ttl: 10.minutes)

    first = service.call("Cadamantis")
    first[:progress_data][:low].clear

    second = service.call("Cadamantis")

    assert_equal 1, second[:progress_data][:low].size
  end

  test "builds progress buckets and aggregated materials" do
    fake_client = Object.new

    fake_client.define_singleton_method(:fetch_character_idx) do |_name|
      123
    end

    fake_client.define_singleton_method(:fetch_collection_details) do |_idx|
      {
        values: [],
        data: [
          {
            "name" => "Tier 1",
            "collections" => [
              {
                "name" => "Near Col",
                "progress" => 85,
                "rewards" => [ { "description" => "ATK +1", "applied" => true } ],
                "data" => [
                  { "name" => "Ticket Especial", "progress" => 1, "max" => 4 }
                ]
              },
              {
                "name" => "Low Col",
                "progress" => 10,
                "rewards" => [ { "description" => "HP +1" } ],
                "missions" => [
                  {
                    "name" => "Mission A",
                    "data" => [
                      { "name" => "Ticket Especial", "progress" => 0, "max" => 2 },
                      { "name" => "Core", "progress" => 0, "max" => 1 }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      }
    end

    snapshot = CollectionSnapshotService.new(client: fake_client).call("Cadamantis")

    assert_equal 123, snapshot[:character_idx]
    assert_equal 1, snapshot[:progress_data][:near].size
    assert_equal 1, snapshot[:progress_data][:low].size

    ticket_row = snapshot[:top_materials].find { |m| m[:name] == "Ticket Especial" }
    assert_not_nil ticket_row
    assert_equal 5, ticket_row[:total_needed]
    assert_equal 2, ticket_row[:collections_count]

    near_ticket = snapshot[:materials_by_bucket][:near].find { |m| m[:name] == "Ticket Especial" }
    assert_not_nil near_ticket
    assert_equal 3, near_ticket[:total_needed]
  end

  test "returns empty buckets when character is not found" do
    fake_client = Object.new
    fake_client.define_singleton_method(:fetch_character_idx) { |_name| nil }
    fake_client.define_singleton_method(:fetch_collection_details) { |_idx| flunk("should not fetch details") }

    snapshot = CollectionSnapshotService.new(client: fake_client).call("Unknown")

    assert_nil snapshot[:character_idx]
    assert_equal({ near: [], mid: [], low: [], below_one: [] }, snapshot[:progress_data])
    assert_equal [], snapshot[:top_materials]
    assert_equal({ near: [], mid: [], low: [], below_one: [] }, snapshot[:materials_by_bucket])
  end

  test "marks reward as unlocked by progress threshold even when applied is false" do
    fake_client = Object.new
    fake_client.define_singleton_method(:fetch_character_idx) { |_name| 456 }

    fake_client.define_singleton_method(:fetch_collection_details) do |_idx|
      {
        values: [],
        data: [
          {
            "name" => "Tier X",
            "collections" => [
              {
                "name" => "Mid Col",
                "progress" => 33,
                "rewards" => [
                  { "description" => "Amp 2%", "applied" => false },
                  { "description" => "Amp 6%", "applied" => false },
                  { "description" => "Amp 15%", "applied" => false }
                ]
              }
            ]
          }
        ]
      }
    end

    snapshot = CollectionSnapshotService.new(client: fake_client).call("Cadamantis")
    mid_collection = snapshot[:progress_data][:mid].first

    assert_not_nil mid_collection
    assert_equal true, mid_collection[:rewards][0][:unlocked]
    assert_equal false, mid_collection[:rewards][1][:unlocked]
    assert_equal false, mid_collection[:rewards][2][:unlocked]
  end
end
