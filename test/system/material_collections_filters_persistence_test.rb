require "application_system_test_case"
require "uri"

class MaterialCollectionsFiltersPersistenceTest < ApplicationSystemTestCase
  test "persists and restores material collections filters via url" do
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
              "data" => [ { "name" => "Material A", "progress" => 0, "max" => 2 } ]
            }
          ]
        }
      ]
    }

    with_stubbed_client(
      fetch_character_idx: ->(_name) { 222 },
      fetch_collection_details: ->(_idx) { details }
    ) do
      visit material_collections_armory_path(name: "X", material: "Material A")

      assert_field "material-collections-name-filter", with: ""
      assert_field "material-collections-bucket-filter", with: ""

      fill_in "material-collections-name-filter", with: "Tier 1"
      fill_in "material-collections-bucket-filter", with: I18n.t("armories.progress.labels.low")

      query = URI.parse(page.current_url).query.to_s
      assert_match(/f_collection=Tier\+1/, query)
      assert_match(/f_bucket=/, query)

      visit page.current_url

      assert_field "material-collections-name-filter", with: "Tier 1"
      assert_field "material-collections-bucket-filter", with: I18n.t("armories.progress.labels.low")
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
