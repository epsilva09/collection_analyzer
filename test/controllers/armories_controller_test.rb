require "test_helper"

class ArmoriesControllerTest < ActionDispatch::IntegrationTest
  test "index displays values when service returns data" do
    details = {
      values: [ "HP +1250", "Defesa +647" ],
      data: [
        { "name" => "Tier 1", "collections" => [ { "name" => "Lago I", "progress" => 93 } ] }
      ]
    }

    with_stubbed_client(
      fetch_character_idx: ->(name) { name == "Cadamantis" ? 75008 : nil },
      fetch_collection_details: ->(idx) { idx == 75008 ? details : { values: [], data: [] } }
    ) do
      get armory_path, params: { name: "Cadamantis" }
      assert_response :success
      assert_includes response.body, "HP +1250"
      assert_includes response.body, "Defesa +647"
      assert_includes response.body, I18n.t("armories.index.actions.view_progress_details")
    end
  end

  test "index shows error when character_idx missing" do
    with_stubbed_client(
      fetch_character_idx: ->(_name) { nil },
      fetch_collection_details: ->(_idx) { { values: [], data: [] } }
    ) do
      get armory_path, params: { name: "Unknown" }
      assert_response :success
      assert_select ".alert", /characterIdx/
    end
  end

  test "compare shows common and unique values" do
    details_a = { values: [ "HP +1250", "Defesa +647", "STR +10" ], data: [] }
    details_b = { values: [ "HP +1250", "INT +5" ], data: [] }

    with_stubbed_client(
      fetch_character_idx: ->(name) { name == "A" ? 1 : (name == "B" ? 2 : nil) },
      fetch_collection_details: ->(idx) { idx == 1 ? details_a : (idx == 2 ? details_b : { values: [], data: [] }) }
    ) do
      get compare_armory_path, params: { name_a: "A", name_b: "B" }
      assert_response :success
      assert_includes response.body, I18n.t("armories.compare.summary")
      assert_includes response.body, I18n.t("armories.compare.only", name: "A")
      assert_includes response.body, I18n.t("armories.compare.only", name: "B")
    end
  end

  test "progress lists collections by progress ranges" do
    details = {
      values: [],
      data: [
        { "name" => "Tier1", "collections" => [
            { "name" => "Low",  "progress" => 10, "rewards" => [ { "description" => "HP +5" } ],
              "data" => [ { "name" => "Material A", "progress" => 0, "max" => 3 } ] },
            { "name" => "Mid",  "progress" => 50, "rewards" => [ { "description" => "DEF +2" } ] },
            { "name" => "Near", "progress" => 82, "rewards" => [ { "description" => "STR +1" } ] }
          ] }
      ]
    }

    with_stubbed_client(
      fetch_character_idx: ->(_name) { 222 },
      fetch_collection_details: ->(_idx) { details }
    ) do
      get progress_armory_path, params: { name: "X" }
      assert_response :success
      assert_includes response.body, I18n.t("armories.progress.labels.low")
      assert_includes response.body, "Low"
      assert_includes response.body, "Material A"
      assert_includes response.body, "Mid"
      assert_includes response.body, "Near"
    end
  end

  test "compare language switch keeps selected characters in query params" do
    details = { values: [ "HP +1" ], data: [] }

    with_stubbed_client(
      fetch_character_idx: ->(_name) { 123 },
      fetch_collection_details: ->(_idx) { details }
    ) do
      get compare_armory_path, params: { name_a: "Popov", name_b: "Cadamantis", locale: "pt-BR" }
      assert_response :success

      # Language switch links should preserve current compare params.
      assert_select 'a[href*="locale=en"][href*="name_a=Popov"][href*="name_b=Cadamantis"]'
      assert_select 'a[href*="locale=pt-BR"][href*="name_a=Popov"][href*="name_b=Cadamantis"]'
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
