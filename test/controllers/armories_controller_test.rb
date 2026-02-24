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
end
