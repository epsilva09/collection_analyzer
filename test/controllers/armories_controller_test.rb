require 'test_helper'

class ArmoriesControllerTest < ActionDispatch::IntegrationTest
  test 'index displays values when service returns data' do
    ArmoryClient.any_instance.stub :fetch_character_idx, 75008 do
      details = {
        values: ['HP +1250', 'Defesa +647'],
        data: [
          { 'name' => 'Tier 1', 'collections' => [{ 'name' => 'Lago I', 'progress' => 93 }] }
        ]
      }
      ArmoryClient.any_instance.stub :fetch_collection_details, details do
        ArmoryClient.any_instance.stub :fetch_collection, details[:values] do
          get armory_path, params: { name: 'Cadamantis' }
          assert_response :success
          assert_select 'li', text: 'HP +1250'
          assert_select 'li', text: 'Defesa +647'
          # index no longer shows near-completion by default
          assert_select 'div.card-header', { count: 0, text: /Collections Near Completion/ }
          assert_select 'a', text: /progress details/ # link to new route
        end
      end
    end
  end

  test 'index shows error when character_idx missing' do
    ArmoryClient.any_instance.stub :fetch_character_idx, nil do
      get armory_path, params: { name: 'Unknown' }
      assert_response :success
      assert_select 'p.error', /characterIdx not found/
    end
  end

  test 'compare shows common and unique values' do
    ArmoryClient.any_instance.stub :fetch_character_idx, 1 do
      details_a = { values: ['HP +1250', 'Defesa +647', 'STR +10'], data: [] }
      ArmoryClient.any_instance.stub :fetch_collection_details, details_a do
        ArmoryClient.any_instance.stub :fetch_character_idx, 2 do
          details_b = { values: ['HP +1250', 'INT +5'], data: [] }
          ArmoryClient.any_instance.stub :fetch_collection_details, details_b do
            get compare_armory_path, params: { name_a: 'A', name_b: 'B' }
            assert_response :success
            assert_select 'h3', text: /Common/ # header exists
            assert_select 'li', text: 'HP +1250'
            assert_select 'section', /Only A/
            # no near completion shown here either
            assert_select 'h6', { count: 0, text: /Near Completion/ }
          end
        end
      end
    end
  end

  test 'progress lists collections by progress ranges' do
    ArmoryClient.any_instance.stub :fetch_character_idx, 222 do
      details = {
        values: [],
        data: [
          { 'name' => 'Tier1', 'collections' => [
              { 'name' => 'Low',  'progress' => 10, 'rewards' => [{ 'description' => 'HP +5' }],
                'data' => [ { 'name' => 'Material A', 'progress' => 0, 'max' => 3 } ] },
              { 'name' => 'Mid',  'progress' => 50, 'rewards' => [{ 'description' => 'DEF +2' }] },
              { 'name' => 'Near', 'progress' => 82, 'rewards' => [{ 'description' => 'STR +1' }] }
            ] }
        ]
      }
      ArmoryClient.any_instance.stub :fetch_collection_details, details do
        get progress_armory_path, params: { name: 'X' }
        assert_response :success
        assert_select 'h2', /Low progress/ # heading for bucket
        assert_select 'li', text: /Low/ # item present
        assert_select 'li', text: /Material A/ # missing material mentioned
        assert_select 'li', text: /Mid/ # item present
        assert_select 'li', text: /Near/ # item present
      end
    end
  end
end
