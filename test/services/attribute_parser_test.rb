require 'test_helper'

class AttributeParserTest < ActiveSupport::TestCase
  test 'parses integer and percent values' do
    values = [
      'HP +1250',
      'Danos Críticos 50%',
      'PVE Defesa +140',
      'INT +3',
      'Resistência ao Dano Crítico 82%'
    ]

    parsed = AttributeParser.parse(values)

    assert_equal 1250.0, parsed['HP'][:value]
    assert_equal :number, parsed['HP'][:unit]

    assert_equal 50.0, parsed['Danos Críticos'][:value]
    assert_equal :percent, parsed['Danos Críticos'][:unit]

    assert_equal 140.0, parsed['PVE Defesa'][:value]
    assert_equal 3.0, parsed['INT'][:value]
    assert_equal 82.0, parsed['Resistência ao Dano Crítico'][:value]
  end
end
