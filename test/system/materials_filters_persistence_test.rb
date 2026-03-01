require "application_system_test_case"
require "uri"

class MaterialsFiltersPersistenceTest < ApplicationSystemTestCase
  test "restores materials filters from URL params" do
    begin
      require "selenium/webdriver/chrome/driver"
    rescue SyntaxError => error
      skip "Skipping system test due to selenium incompatibility: #{error.message}"
    end

    details = {
      values: [],
      data: [
        {
          "name" => "Tier1",
          "collections" => [
            {
              "name" => "Low",
              "progress" => 10,
              "rewards" => [ { "description" => "HP +5" } ],
              "data" => [ { "name" => "Material A", "progress" => 0, "max" => 3 } ]
            },
            {
              "name" => "Mid",
              "progress" => 50,
              "rewards" => [ { "description" => "DEF +2" } ],
              "data" => [ { "name" => "Material B", "progress" => 0, "max" => 3 } ]
            }
          ]
        }
      ]
    }

    with_stubbed_client(
      fetch_character_idx: ->(_name) { 222 },
      fetch_collection_details: ->(_idx) { details }
    ) do
      visit materials_armory_path(name: "X")

      assert_field "materials-name-filter", with: ""
      assert_field "materials-bucket-filter", with: ""

      fill_in "materials-name-filter", with: "Material A"
      fill_in "materials-bucket-filter", with: I18n.t("armories.progress.labels.low")

      assert_match(/f_material=Material\+A/, URI.parse(page.current_url).query.to_s)
      assert_match(/f_bucket=/, URI.parse(page.current_url).query.to_s)

      visit page.current_url

      assert_field "materials-name-filter", with: "Material A"
      assert_field "materials-bucket-filter", with: I18n.t("armories.progress.labels.low")
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
