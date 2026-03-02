require "test_helper"

class TrackedCharactersRegistryServiceTest < ActiveSupport::TestCase
  test "tracks character and updates last seen on subsequent calls" do
    service = TrackedCharactersRegistryService.new

    first = service.track!(name: "Cadamantis", character_idx: 75008, locale: :"pt-BR")
    second = service.track!(name: "Cadamantis Updated", character_idx: 75008, locale: :en)

    assert_equal first.id, second.id
    assert_equal "Cadamantis Updated", second.character_name
    assert_equal "en", second.locale
    assert second.last_seen_at.present?
  end
end
