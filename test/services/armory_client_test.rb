require "test_helper"
require "json"
require "ostruct"

class ArmoryClientTest < ActiveSupport::TestCase
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
end
