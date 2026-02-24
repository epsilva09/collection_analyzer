require 'test_helper'

class ArmoriesControllerTest < ActionDispatch::IntegrationTest
  test 'index displays values when service returns data' do
    client = ArmoryClient.new
    # stub methods on the instance used in controller
    ArmoryClient.any_instance.stub :fetch_character_idx, 75008 do
      ArmoryClient.any_instance.stub :fetch_collection, ['HP +1250', 'Defesa +647'] do
        get armory_path, params: { name: 'Cadamantis' }
        assert_response :success
        assert_select 'li', text: 'HP +1250'
        assert_select 'li', text: 'Defesa +647'
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
      ArmoryClient.any_instance.stub :fetch_collection, ['HP +1250', 'Defesa +647', 'STR +10'] do
        # For second character, return a different set
        ArmoryClient.any_instance.stub :fetch_character_idx, 2 do
          ArmoryClient.any_instance.stub :fetch_collection, ['HP +1250', 'INT +5'] do
            get compare_armory_path, params: { name_a: 'A', name_b: 'B' }
            assert_response :success
            assert_select 'h3', text: /Common/ # header exists
            assert_select 'li', text: 'HP +1250'
            assert_select 'section', /Only A/ 
          end
        end
      end
    end
  end
end
