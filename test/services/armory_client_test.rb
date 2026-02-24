require 'test_helper'
require 'json'

class ArmoryClientTest < ActiveSupport::TestCase
  test 'fetch_character_idx returns id when API responds' do
    fake = Object.new
    def fake.get(*)
      OpenStruct.new(body: { character: { characterIdx: 12345 } }.to_json)
    end

    client = ArmoryClient.new(fake)
    assert_equal 12345, client.fetch_character_idx('Name')
  end

  test 'fetch_collection returns values array' do
    fake = Object.new
    def fake.get(*)
      OpenStruct.new(body:({ values: ['HP +10', 'STR +5'] }.to_json))
    end

    client = ArmoryClient.new(fake)
    assert_equal ['HP +10', 'STR +5'], client.fetch_collection(123)
  end
end
