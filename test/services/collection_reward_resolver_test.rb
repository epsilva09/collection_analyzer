require "test_helper"

class CollectionRewardResolverTest < ActiveSupport::TestCase
  test "recalculates values from collection progress thresholds" do
    details = {
      values: [ "Aumentou todas as técnicas Amp. 45%" ],
      data: [
        {
          "name" => "Templo",
          "collections" => [
            collection_payload("Templo esquecido 2ss", 100, [ 2, 4, 6 ]),
            collection_payload("Cidade Abandonada", 100, [ 4, 8, 12 ]),
            collection_payload("Pandemônio II", 80, [ 2, 4, 6 ], applied: [ true, false, false ]),
            collection_payload("Solo Flamejante II", 60, [ 1, 2, 5 ], applied: [ true, false, false ]),
            collection_payload("Aprimoramento Divino", 100, [ 1, 3, 5 ]),
            collection_payload("Acessório - Bracelete", 100, [ 2, 4, 7 ]),
            collection_payload("Cheque o mec. de atk", 60, [ 2, 4, 8 ], applied: [ true, false, false ]),
            collection_payload("Retaliação do chefe governante III", 100, [ 2, 5, 8 ])
          ]
        }
      ]
    }

    resolved = CollectionRewardResolver.resolve(details)

    assert_includes resolved[:values], "Aumentou todas as técnicas Amp. 48%"

    pandemônio = resolved[:data].first["collections"].find { |entry| entry["name"] == "Pandemônio II" }
    solo = resolved[:data].first["collections"].find { |entry| entry["name"] == "Solo Flamejante II" }
    cheque = resolved[:data].first["collections"].find { |entry| entry["name"] == "Cheque o mec. de atk" }

    assert_equal [ true, true, false ], pandemônio["rewards"].map { |reward| reward["applied"] }
    assert_equal [ true, true, false ], solo["rewards"].map { |reward| reward["applied"] }
    assert_equal [ true, true, false ], cheque["rewards"].map { |reward| reward["applied"] }
  end

  test "falls back to raw values when collection data is unavailable" do
    details = { values: [ "HP +100", "INT +5" ], data: nil }

    resolved = CollectionRewardResolver.resolve(details)

    assert_equal [ "HP +100", "INT +5" ], resolved[:values]
    assert_equal [], resolved[:data]
  end

  test "emits divergence notification when payload summary differs" do
    details = {
      values: [ "Aumentou todas as técnicas Amp. 45%" ],
      data: [
        {
          "name" => "Tier 1",
          "collections" => [
            collection_payload("Solo Flamejante II", 60, [ 1, 2, 5 ], applied: [ true, false, false ])
          ]
        }
      ]
    }

    events = []
    subscriber = ActiveSupport::Notifications.subscribe("collection_reward_resolver.values_divergence") do |_name, _start, _finish, _id, payload|
      events << payload
    end

    CollectionRewardResolver.resolve(details, context: { source: "test", character_name: "Cadamantis", character_idx: 75008 })

    assert_equal 1, events.size
    event = events.first
    assert_equal "test", event[:source]
    assert_equal "Cadamantis", event[:character_name]
    assert_equal 75008, event[:character_idx]
    assert_equal [ "Aumentou todas as técnicas Amp. 45%" ], event[:raw_values]
    assert_equal [ "Aumentou todas as técnicas Amp. 2%" ], event[:resolved_values]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  private

  def collection_payload(name, progress, reward_values, applied: nil)
    rewards = reward_values.each_with_index.map do |value, index|
      reward = { "description" => "Aumentou todas as técnicas Amp. #{value}%" }
      reward["applied"] = applied[index] unless applied.nil?
      reward
    end

    {
      "name" => name,
      "progress" => progress,
      "rewards" => rewards
    }
  end
end