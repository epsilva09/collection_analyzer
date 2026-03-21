require "httparty"

class ArmoryClient
  BASE_URL = ENV.fetch("ASC_API_BASE_URL", "https://api.cabalascension.com")
  DEFAULT_CACHE_TTL = 5.minutes
  REQUEST_TIMEOUT = 8

  def initialize(http_client = HTTParty, cache: Rails.cache, cache_ttl: DEFAULT_CACHE_TTL)
    @http = http_client
    @cache = cache
    @cache_ttl = cache_ttl
  end

  # Returns integer characterIdx or nil
  def fetch_character_idx(name)
    key = cache_key("character_idx", name.to_s.downcase)

    fetch_cached(key) do
      resp = @http.get("#{BASE_URL}/api/website/armory", request_options(query: { name: name }))
      parsed = parse_response(resp)
      parsed.dig("character", "characterIdx")
    end
  end

  # Returns array of values or empty array
  # Basic collection endpoint. Returns just the array of string values.
  def fetch_collection(character_idx)
    details = fetch_collection_details(character_idx)
    details[:values] || []
  end

  # When the API returns extra metadata (progress, missions, etc.) we need
  # to preserve it so views can surface "near completion" collections.  This
  # method returns a hash containing the raw values plus the optional data
  # structure.  It intentionally does not mutate the return value of
  # fetch_collection so existing callers remain untouched.
  def fetch_collection_details(character_idx)
    key = cache_key("collection_details", character_idx)

    fetch_cached(key) do
      resp = @http.get("#{BASE_URL}/api/website/armory/collection/#{character_idx}", request_options)
      parsed = parse_response(resp)
      {
        values: parsed["values"] || [],
        data: parsed["data"] || []
      }
    end
  end

  # Returns normalized myth payload hash
  def fetch_myth(character_idx)
    key = cache_key("myth", character_idx)

    fetch_cached(key) do
      resp = @http.get("#{BASE_URL}/api/website/armory/myth/#{character_idx}", request_options)
      ArmoryMythNormalizer.call(parse_response(resp))
    end
  end

  # Returns normalized force-wing payload hash
  def fetch_force_wing(character_idx)
    key = cache_key("force_wing", character_idx)

    fetch_cached(key) do
      resp = @http.get("#{BASE_URL}/api/website/armory/force-wing/#{character_idx}", request_options)
      ArmoryForceWingNormalizer.call(parse_response(resp))
    end
  end

  # Returns normalized honor-medal payload hash
  def fetch_honor_medal(character_idx, medal_type: 2)
    key = cache_key("honor_medal", "#{medal_type}:#{character_idx}")

    fetch_cached(key) do
      resp = @http.get("#{BASE_URL}/api/website/armory/honor-medal/#{medal_type}/#{character_idx}", request_options)
      ArmoryHonorMedalNormalizer.call(parse_response(resp))
    end
  end

  # Returns normalized stellar payload hash
  def fetch_stellar(character_idx)
    key = cache_key("stellar", character_idx)

    fetch_cached(key) do
      resp = @http.get("#{BASE_URL}/api/website/armory/stellar/#{character_idx}", request_options)
      ArmoryStellarNormalizer.call(parse_response(resp))
    end
  end

  # Returns normalized ability payload hash
  def fetch_ability(character_idx)
    key = cache_key("ability", character_idx)

    fetch_cached(key) do
      resp = @http.get("#{BASE_URL}/api/website/armory/ability/#{character_idx}", request_options)
      ArmoryAbilityNormalizer.call(parse_response(resp))
    end
  end

  private

  def cache_key(prefix, value)
    "armory_client:#{prefix}:#{value}"
  end

  def json_headers
    { "Accept" => "application/json" }
  end

  def request_options(query: nil)
    options = { headers: json_headers, timeout: REQUEST_TIMEOUT }
    options[:query] = query if query.present?
    options
  end

  def fetch_cached(key)
    return yield unless @cache

    @cache.fetch(key, expires_in: @cache_ttl) do
      yield
    end
  end

  def parse_response(resp)
    body = resp.respond_to?(:body) ? resp.body : resp
    JSON.parse(body)
  rescue JSON::ParserError => e
    raise "Invalid JSON response: #{e.message}"
  end
end
