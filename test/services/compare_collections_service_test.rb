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
end
