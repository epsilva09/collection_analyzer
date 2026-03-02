require "application_system_test_case"
require "uri"

class CompareFiltersBehaviorTest < ApplicationSystemTestCase
  test "filters compare table by attribute and winner with csv inputs" do
    begin
      require "selenium/webdriver/chrome/driver"
    rescue SyntaxError => error
      skip "Skipping system test due to selenium incompatibility: #{error.message}"
    end

    details_a = {
      values: [ "HP +1250", "Defesa +647", "STR +10" ],
      data: []
    }
    details_b = {
      values: [ "HP +1250", "INT +5" ],
      data: []
    }

    with_stubbed_client(
      fetch_character_idx: ->(name) { name == "A" ? 1 : (name == "B" ? 2 : nil) },
      fetch_collection_details: ->(idx) { idx == 1 ? details_a : (idx == 2 ? details_b : { values: [], data: [] }) }
    ) do
      visit compare_armory_path(name_a: "A", name_b: "B")

      assert_field "compare-attribute-filter", with: ""
      assert_field "compare-winner-filter", with: ""

      fill_in "compare-attribute-filter", with: "HP"
      assert_selector "tr[data-compare-row='true']:not([hidden])", count: 1

      fill_in "compare-attribute-filter", with: "HP, INT"
      assert_selector "tr[data-compare-row='true']:not([hidden])", minimum: 1

      fill_in "compare-winner-filter", with: "A"
      assert_selector "tr[data-compare-row='true']:not([hidden])", minimum: 1

      click_button I18n.t("armories.compare.filters.clear")
      assert_field "compare-attribute-filter", with: ""
      assert_field "compare-winner-filter", with: ""
      assert_selector "tr[data-compare-row='true']:not([hidden])", minimum: 1
    end
  end

  private

  def with_stubbed_client(fetch_character_idx:, fetch_collection_details:)
    fake_client = Object.new
    fake_client.define_singleton_method(:fetch_character_idx, &fetch_character_idx)
    fake_client.define_singleton_method(:fetch_collection_details, &fetch_collection_details)

    original_new = ArmoryClient.method(:new)
    ArmoryClient.define_singleton_method(:new) { |_http_client = HTTParty| fake_client }

    begin
      yield
    ensure
      ArmoryClient.define_singleton_method(:new, original_new)
    end
  end
end
