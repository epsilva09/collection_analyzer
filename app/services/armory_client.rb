require "httparty"

class ArmoryClient
  BASE_URL = ENV.fetch("ASC_API_BASE_URL", "https://asc-api-admin.atkz.dev")
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
