require "test_helper"

class CompareCollectionsServiceTest < ActiveSupport::TestCase
  test "returns not ready and avoids API calls when one name is missing" do
    fake_client = Object.new
    fake_client.define_singleton_method(:fetch_character_idx) { |_name| flunk("should not call API") }
    fake_client.define_singleton_method(:fetch_collection_details) { |_idx| flunk("should not call API") }

    payload = CompareCollectionsService.new(client: fake_client).call(name_a: "A", name_b: nil)

    assert_equal false, payload[:comparison_ready]
    assert_equal "A", payload[:result][:name_a]
    assert_nil payload[:result][:name_b]
    assert_equal [], payload[:result][:values_a]
    assert_equal [], payload[:result][:values_b]
  end

  test "builds comparison details and common/unique sets" do
    fake_client = Object.new

    fake_client.define_singleton_method(:fetch_character_idx) do |name|
      name == "A" ? 1 : 2
    end

    fake_client.define_singleton_method(:fetch_collection_details) do |idx|
      if idx == 1
        {
          values: [
            "HP +10",
            "PVE Todos os Ataques 7%"
          ],
          data: []
        }
      else
        {
          values: [
            "HP +5",
            "INT +3"
          ],
          data: []
        }
      end
    end

    payload = CompareCollectionsService.new(client: fake_client).call(name_a: "A", name_b: "B")
    result = payload[:result]

    assert_equal true, payload[:comparison_ready]
    assert_equal 1, result[:character_idx_a]
    assert_equal 2, result[:character_idx_b]

    assert_includes result[:common], "HP"
    assert_includes result[:only_a], "PVE Todos os Ataques"
    assert_includes result[:only_b], "INT"

    pve_row = result[:detailed_ordered].find { |row| row[:attribute] == "PVE Todos os Ataques" }
    assert_not_nil pve_row
    assert_equal true, pve_row[:is_special]
  end

  test "resolves values from collection progress before comparing" do
    fake_client = Object.new

    fake_client.define_singleton_method(:fetch_character_idx) do |name|
      name == "A" ? 1 : 2
    end

    fake_client.define_singleton_method(:fetch_collection_details) do |idx|
      if idx == 1
        {
          values: [ "Aumentou todas as técnicas Amp. 45%" ],
          data: [
            {
              "name" => "Tier 1",
              "collections" => [
                {
                  "name" => "Solo Flamejante II",
                  "progress" => 60,
                  "rewards" => [
                    { "description" => "Aumentou todas as técnicas Amp. 1%", "applied" => true },
                    { "description" => "Aumentou todas as técnicas Amp. 2%", "applied" => false },
                    { "description" => "Aumentou todas as técnicas Amp. 5%", "applied" => false }
                  ]
                },
                {
                  "name" => "Cheque o mec. de atk",
                  "progress" => 60,
                  "rewards" => [
                    { "description" => "Aumentou todas as técnicas Amp. 2%", "applied" => true },
                    { "description" => "Aumentou todas as técnicas Amp. 4%", "applied" => false },
                    { "description" => "Aumentou todas as técnicas Amp. 8%", "applied" => false }
                  ]
                }
              ]
            }
          ]
        }
      else
        {
          values: [ "Aumentou todas as técnicas Amp. 1%" ],
          data: [
            {
              "name" => "Tier 1",
              "collections" => [
                {
                  "name" => "Solo Flamejante II",
                  "progress" => 30,
                  "rewards" => [
                    { "description" => "Aumentou todas as técnicas Amp. 1%" },
                    { "description" => "Aumentou todas as técnicas Amp. 2%" },
                    { "description" => "Aumentou todas as técnicas Amp. 5%" }
                  ]
                }
              ]
            }
          ]
        }
      end
    end

    payload = CompareCollectionsService.new(client: fake_client).call(name_a: "A", name_b: "B")
    result = payload[:result]

    assert_includes result[:values_a], "Aumentou todas as técnicas Amp. 6%"
    row = result[:detailed].find { |entry| entry[:attribute] == "Aumentou todas as técnicas Amp." }
    assert_not_nil row
    assert_equal 6.0, row[:value_a]
    assert_equal 1.0, row[:value_b]
  end

  test "summarizes total and winner from completed collections" do
    fake_client = Object.new

    fake_client.define_singleton_method(:fetch_character_idx) do |name|
      name == "A" ? 1 : 2
    end

    fake_client.define_singleton_method(:fetch_collection_details) do |idx|
      if idx == 1
        {
          values: [],
          data: [
            {
              "name" => "Tier 1",
              "collections" => [
                { "name" => "C1", "progress" => 100, "rewards" => [] },
                { "name" => "C2", "progress" => 100, "rewards" => [] },
                { "name" => "C3", "progress" => 50, "rewards" => [] }
              ]
            }
          ]
        }
      else
        {
          values: [],
          data: [
            {
              "name" => "Tier 1",
              "collections" => [
                { "name" => "C1", "progress" => 100, "rewards" => [] },
                { "name" => "C2", "progress" => 70, "rewards" => [] },
                { "name" => "C3", "progress" => 100, "rewards" => [] },
                { "name" => "C4", "progress" => 100, "rewards" => [] }
              ]
            }
          ]
        }
      end
    end

    payload = CompareCollectionsService.new(client: fake_client).call(name_a: "A", name_b: "B")
    summary = payload.dig(:result, :collection_comparison_summary)

    assert_equal 4, summary[:total]
    assert_equal 3, summary[:total_a]
    assert_equal 4, summary[:total_b]
    assert_equal 1, summary[:completed_both]
    assert_equal 1, summary[:completed_only_a]
    assert_equal 2, summary[:completed_only_b]
    assert_equal 2, summary[:completed_total_a]
    assert_equal 3, summary[:completed_total_b]
    assert_equal :b, summary[:winner]
  end
end
