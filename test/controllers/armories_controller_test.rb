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
      assert_includes response.body, I18n.t("armories_shared.menu.progress")
    end
  end

  test "index recalculates summary values from collection progress" do
    details = {
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
            },
            {
              "name" => "Retaliação do chefe governante III",
              "progress" => 100,
              "rewards" => [
                { "description" => "Aumentou todas as técnicas Amp. 2%" },
                { "description" => "Aumentou todas as técnicas Amp. 5%" },
                { "description" => "Aumentou todas as técnicas Amp. 8%" }
              ]
            }
          ]
        }
      ]
    }

    with_stubbed_client(
      fetch_character_idx: ->(_name) { 75008 },
      fetch_collection_details: ->(_idx) { details }
    ) do
      get armory_path, params: { name: "Cadamantis", format: :json }

      assert_response :success

      body = JSON.parse(response.body)
      assert_includes body["values"], "Aumentou todas as técnicas Amp. 14%"
      refute_includes body["values"], "Aumentou todas as técnicas Amp. 45%"
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

  test "compare collections shows per-collection progress and bonuses for both characters" do
    details_a = {
      values: [ "HP +100" ],
      data: [
        {
          "name" => "Mundo",
          "collections" => [
            {
              "name" => "Elo Perdido I",
              "progress" => 100,
              "rewards" => [
                { "description" => "Ignorar Acerto +70" },
                { "description" => "Ignorar Acerto +150" },
                { "description" => "Ignorar Acerto +300" }
              ]
            }
          ]
        }
      ]
    }

    details_b = {
      values: [ "HP +90" ],
      data: [
        {
          "name" => "Mundo",
          "collections" => [
            {
              "name" => "Elo Perdido I",
              "progress" => 64,
              "rewards" => [
                { "description" => "Ignorar Acerto +70" },
                { "description" => "Ignorar Acerto +150" },
                { "description" => "Ignorar Acerto +300" }
              ]
            }
          ]
        }
      ]
    }

    with_stubbed_client(
      fetch_character_idx: ->(name) { name == "A" ? 1 : (name == "B" ? 2 : nil) },
      fetch_collection_details: ->(idx) { idx == 1 ? details_a : (idx == 2 ? details_b : { values: [], data: [] }) }
    ) do
      get compare_collections_armory_path, params: { name_a: "A", name_b: "B" }

      assert_response :success
      assert_includes response.body, I18n.t("armories.compare_collections.heading")
      assert_includes response.body, "Mundo / Elo Perdido I"
      assert_includes response.body, "100%"
      assert_includes response.body, "64%"
      assert_includes response.body, "300 vs 150"
      assert_includes response.body, "100%"
      assert_includes response.body, "Ignorar Acerto +300"
      assert_includes response.body, "armory-bonus-badge--unlocked"
      assert_includes response.body, "armory-bonus-badge--locked"
    end
  end

  test "compare collections filters by pending status and collection name" do
    details_a = {
      values: [],
      data: [
        {
          "name" => "Mundo",
          "collections" => [
            { "name" => "Elo Perdido I", "progress" => 53, "rewards" => [ { "description" => "ATK +1" } ] },
            { "name" => "Elo Perdido II", "progress" => 100, "rewards" => [ { "description" => "ATK +1" } ] }
          ]
        }
      ]
    }

    details_b = {
      values: [],
      data: [
        {
          "name" => "Mundo",
          "collections" => [
            { "name" => "Elo Perdido I", "progress" => 40, "rewards" => [ { "description" => "ATK +1" } ] },
            { "name" => "Elo Perdido II", "progress" => 100, "rewards" => [ { "description" => "ATK +1" } ] }
          ]
        }
      ]
    }

    with_stubbed_client(
      fetch_character_idx: ->(name) { name == "A" ? 1 : (name == "B" ? 2 : nil) },
      fetch_collection_details: ->(idx) { idx == 1 ? details_a : (idx == 2 ? details_b : { values: [], data: [] }) }
    ) do
      get compare_collections_armory_path,
        params: { name_a: "A", name_b: "B", collection_status: "pending_both", collection_name: "Elo Perdido I" }

      assert_response :success
      assert_includes response.body, "Elo Perdido I"
      assert_not_includes response.body, "Elo Perdido II"
    end
  end

  test "compare overview shows summary and progression gaps" do
    fake_service = Object.new
    fake_service.define_singleton_method(:empty_result) do |name_a, name_b|
      {
        name_a: name_a,
        name_b: name_b,
        comparison_cards: [],
        progression_gaps: []
      }
    end

    fake_service.define_singleton_method(:call) do |name_a:, name_b:|
      {
        comparison_ready: true,
        result: {
          name_a: name_a,
          name_b: name_b,
          comparison_cards: [
            { metric: :level, label_key: "level", value_a: 200, value_b: 190, diff: 10 }
          ],
          weighted_profiles: {
            pve: {
              score_a: 100,
              score_b: 91.2,
              diff: 8.8,
              contributions: [ { metric: :attack_power_pve, label_key: "attack_power_pve", weight: 0.36, weighted_a: 36.0, weighted_b: 33.0, diff: 3.0 } ]
            },
            pvp: {
              score_a: 100,
              score_b: 90.5,
              diff: 9.5,
              contributions: [ { metric: :attack_power_pvp, label_key: "attack_power_pvp", weight: 0.36, weighted_a: 36.0, weighted_b: 32.7, diff: 3.3 } ]
            },
            overall: {
              score_a: 96.5,
              score_b: 87.6,
              diff: 8.9
            }
          },
          collection_macro: {
            a: { total: 10, completed: 5, in_progress: 3, near_completion: 2, average_progress: 66.5, unlocked_reward_tiers: 12, reward_tiers_total: 30 },
            b: { total: 10, completed: 4, in_progress: 4, near_completion: 1, average_progress: 58.0, unlocked_reward_tiers: 9, reward_tiers_total: 30 },
            completed_diff: 1,
            average_progress_diff: 8.5,
            near_completion_diff: 1,
            unlocked_reward_diff: 3
          },
          progression_gaps: [
            { system: :myth, label_key: "myth", value_a: 80, value_b: 70, diff: 10, detail_a: "Michael", detail_b: "Uriel" }
          ]
        }
      }
    end

    original_new = CompareOverviewService.method(:new)
    CompareOverviewService.define_singleton_method(:new) { fake_service }

    begin
      get compare_overview_armory_path, params: { name_a: "A", name_b: "B" }
      assert_response :success
      assert_includes response.body, I18n.t("armories.compare_overview.heading")
      assert_includes response.body, I18n.t("armories.compare_overview.summary_heading")
      assert_includes response.body, I18n.t("armories.compare_overview.weighted_heading")
      assert_includes response.body, I18n.t("armories.compare_overview.collection_heading")
      assert_includes response.body, I18n.t("armories.compare_overview.progression_heading")
      assert_includes response.body, "200"
      assert_includes response.body, "190"
    ensure
      CompareOverviewService.define_singleton_method(:new, original_new)
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
      assert_includes response.body, I18n.t("armories.progress.history.heading")
      assert_includes response.body, I18n.t("armories.progress.history.view_changes")
      assert_includes response.body, I18n.t("armories.progress.filters.status_label")
      assert_includes response.body, I18n.t("armories.progress.filters.item_label")
      assert_includes response.body, "Low"
      assert_includes response.body, "Mid"
      assert_includes response.body, "Near"
      assert TrackedCharacter.exists?(character_idx: 222)
    end
  end

  test "materials lists aggregated required items by bucket and general view" do
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
      get materials_armory_path, params: { name: "X" }
      assert_response :success
      # Should show per-bucket aggregated materials and a general view.
      assert_includes response.body, I18n.t("armories.progress.labels.low")
      assert_includes response.body, I18n.t("armories.materials.labels.general")
      assert_includes response.body, "Material A"
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

  test "compare renders detailed table filters and row filter attributes" do
    details_a = { values: [ "HP +1250", "Defesa +647", "STR +10" ], data: [] }
    details_b = { values: [ "HP +1250", "INT +5" ], data: [] }

    with_stubbed_client(
      fetch_character_idx: ->(name) { name == "A" ? 1 : (name == "B" ? 2 : nil) },
      fetch_collection_details: ->(idx) { idx == 1 ? details_a : (idx == 2 ? details_b : { values: [], data: [] }) }
    ) do
      get compare_armory_path, params: { name_a: "A", name_b: "B" }
      assert_response :success

      assert_includes response.body, "data-controller=\"compare-table-filters\""
      assert_select "#compare-attribute-filter"
      assert_select "#compare-winner-filter"
      assert_select "datalist#compare-attribute-options option", minimum: 1
      assert_select "tbody tr[data-compare-row='true']", minimum: 1
    end
  end

  test "compare renders localized filter labels and hints" do
    details_a = { values: [ "HP +1250", "Defesa +647" ], data: [] }
    details_b = { values: [ "HP +1250", "INT +5" ], data: [] }

    with_stubbed_client(
      fetch_character_idx: ->(name) { name == "A" ? 1 : (name == "B" ? 2 : nil) },
      fetch_collection_details: ->(idx) { idx == 1 ? details_a : (idx == 2 ? details_b : { values: [], data: [] }) }
    ) do
      get compare_armory_path, params: { name_a: "A", name_b: "B", locale: "pt-BR" }
      assert_response :success
      assert_includes response.body, I18n.t("armories.compare.filters.heading", locale: :"pt-BR")
      assert_includes response.body, I18n.t("armories.compare.filters.multi_hint", locale: :"pt-BR")

      get compare_armory_path, params: { name_a: "A", name_b: "B", locale: "en" }
      assert_response :success
      assert_includes response.body, I18n.t("armories.compare.filters.heading", locale: :en)
      assert_includes response.body, I18n.t("armories.compare.filters.multi_hint", locale: :en)
    end
  end

  test "material collections renders filter controls and row filter metadata" do
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
      get material_collections_armory_path, params: { name: "X", material: "Material A" }
      assert_response :success

      assert_includes response.body, "data-controller=\"material-collections-filters\""
      assert_select "#material-collections-name-filter"
      assert_select "#material-collections-bucket-filter"
      assert_select "tr[data-material-collections-entry='true']", minimum: 1
    end
  end

  test "progress shows localized invalid JSON error message" do
    with_stubbed_client(
      fetch_character_idx: ->(_name) { raise "Invalid JSON response: unexpected token at '{'" },
      fetch_collection_details: ->(_idx) { { values: [], data: [] } }
    ) do
      get progress_armory_path, params: { name: "X" }
      assert_response :success
      assert_includes response.body, "Resposta JSON inválida"
      assert_includes response.body, "unexpected token at"
    end
  end

  test "progress changes shows changed collections compared to previous snapshot" do
    locale = I18n.locale.to_s

    CollectionProgressSnapshot.create!(
      character_name: "X",
      character_idx: 222,
      locale: locale,
      captured_on: Date.new(2026, 3, 1),
      captured_at: Time.zone.parse("2026-03-01 09:00"),
      total_collections: 3,
      completed_collections: 0,
      near_count: 1,
      mid_count: 1,
      low_count: 1,
      below_one_count: 0,
      completion_rate: 0,
      collections_payload: [
        {
          key: "Tier1::Low",
          tier: "Tier1",
          name: "Low",
          bucket: "low",
          progress: 10,
          missing: 90,
          materials: [ { name: "Material A", needed: 3 } ]
        }
      ]
    )

    current_snapshot = CollectionProgressSnapshot.create!(
      character_name: "X",
      character_idx: 222,
      locale: locale,
      captured_on: Date.new(2026, 3, 2),
      captured_at: Time.zone.parse("2026-03-02 14:00"),
      total_collections: 3,
      completed_collections: 1,
      near_count: 0,
      mid_count: 1,
      low_count: 1,
      below_one_count: 0,
      completion_rate: 33.33,
      collections_payload: [
        {
          key: "Tier1::Low",
          tier: "Tier1",
          name: "Low",
          bucket: "mid",
          progress: 35,
          missing: 65,
          materials: [ { name: "Material A", needed: 1 } ]
        }
      ]
    )

    get progress_changes_armory_path,
      params: { name: "X", character_idx: 222, snapshot_id: current_snapshot.id, locale: locale, change_type: "updated" }

    assert_response :success
    assert_includes response.body, "Tier1 / Low"
    assert_includes response.body, "10%"
    assert_includes response.body, "35%"
    assert_includes response.body, "Material A"
  end

  test "progress history defaults to changed snapshots and can show all" do
    locale = "pt-BR"

    CollectionProgressSnapshot.create!(
      character_name: "X",
      character_idx: 222,
      locale: locale,
      captured_on: Date.new(2026, 3, 1),
      captured_at: Time.zone.parse("2026-03-01 08:00"),
      total_collections: 3,
      completed_collections: 1,
      near_count: 1,
      mid_count: 1,
      low_count: 0,
      below_one_count: 0,
      completion_rate: 33.33,
      has_changes: false,
      changes_count: 0,
      collections_payload: []
    )

    details = {
      values: [],
      data: [
        { "name" => "Tier1", "collections" => [
            { "name" => "Near", "progress" => 82, "rewards" => [ { "description" => "STR +1" } ] }
          ] }
      ]
    }

    with_stubbed_client(
      fetch_character_idx: ->(_name) { 222 },
      fetch_collection_details: ->(_idx) { details }
    ) do
      get progress_armory_path, params: { name: "X", locale: locale }
      assert_response :success
      assert_includes response.body, I18n.t("armories.progress.history.visibility_changed")
      assert_not_includes response.body, I18n.t("armories.progress.history.unchanged_badge")

      get progress_armory_path, params: { name: "X", history_visibility: "all", locale: locale }
      assert_response :success
      assert_includes response.body, I18n.t("armories.progress.history.unchanged_badge")
    end
  end

  test "progress changes does not mark collection as completed when progress is 100 but materials are still pending" do
    locale = I18n.locale.to_s

    previous_snapshot = CollectionProgressSnapshot.create!(
      character_name: "Cadamantis",
      character_idx: 75008,
      locale: locale,
      captured_on: Date.new(2026, 3, 4),
      captured_at: Time.zone.parse("2026-03-04 09:00"),
      total_collections: 10,
      completed_collections: 4,
      near_count: 1,
      mid_count: 1,
      low_count: 1,
      below_one_count: 0,
      completion_rate: 40.0,
      collections_payload: [
        {
          key: "TierDivino::AprimoramentoDivino",
          tier: "TierDivino",
          name: "Aprimoramento Divino",
          bucket: "near",
          progress: 99,
          missing: 1,
          inconsistent_progress: false,
          materials: [
            { name: "Conversor Divino - Moto", needed: 1 },
            { name: "Nucleo divino", needed: 4998 }
          ]
        }
      ]
    )

    current_snapshot = CollectionProgressSnapshot.create!(
      character_name: "Cadamantis",
      character_idx: 75008,
      locale: locale,
      captured_on: Date.new(2026, 3, 5),
      captured_at: Time.zone.parse("2026-03-05 09:00"),
      total_collections: 10,
      completed_collections: 4,
      near_count: 1,
      mid_count: 1,
      low_count: 1,
      below_one_count: 0,
      completion_rate: 40.0,
      collections_payload: [
        {
          key: "TierDivino::AprimoramentoDivino",
          tier: "TierDivino",
          name: "Aprimoramento Divino",
          bucket: "near",
          progress: 100,
          missing: 0,
          inconsistent_progress: true,
          materials: [
            { name: "Conversor Divino - Moto", needed: 1 },
            { name: "Nucleo divino", needed: 4997 }
          ]
        }
      ]
    )

    get progress_changes_armory_path,
      params: { name: "Cadamantis", character_idx: 75008, snapshot_id: current_snapshot.id, locale: locale }

    assert_response :success
    assert_includes response.body, "Aprimoramento Divino"
    assert_select "table.progress-changes-table tbody tr td span.progress-change-type", text: I18n.t("armories.progress.changes.types.updated"), count: 1
    assert_select "table.progress-changes-table tbody tr td span.progress-change-type", text: I18n.t("armories.progress.changes.types.completed"), count: 0
    assert_includes response.body, I18n.t("armories.progress.badges.inconsistent_data")
    assert_not_includes response.body, "Conversor Divino - Moto"
    assert_includes response.body, "4998"
    assert_includes response.body, "4997"

    get progress_changes_armory_path,
      params: {
        name: "Cadamantis",
        character_idx: 75008,
        snapshot_id: current_snapshot.id,
        locale: locale,
        show_stable_materials: "1"
      }

    assert_response :success
    assert_includes response.body, I18n.t("armories.progress.changes.stable_materials_heading")
    assert_includes response.body, "Conversor Divino - Moto"
    assert_includes response.body, "1→1"
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
