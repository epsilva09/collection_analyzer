require 'httparty'

class ArmoryClient
  BASE_URL = ENV.fetch('ASC_API_BASE_URL', 'https://asc-api-admin.atkz.dev')

  def initialize(http_client = HTTParty)
    @http = http_client
  end

  # Returns integer characterIdx or nil
  def fetch_character_idx(name)
    resp = @http.get("#{BASE_URL}/api/website/armory", query: { name: name }, headers: { 'Accept' => 'application/json' })
    parsed = parse_response(resp)
    parsed.dig('character', 'characterIdx')
  end

  # Returns array of values or empty array
  # Basic collection endpoint. Returns just the array of string values.
  def fetch_collection(character_idx)
    resp = @http.get("#{BASE_URL}/api/website/armory/collection/#{character_idx}", headers: { 'Accept' => 'application/json' })
    parsed = parse_response(resp)
    parsed['values'] || []
  end

  # When the API returns extra metadata (progress, missions, etc.) we need
  # to preserve it so views can surface "near completion" collections.  This
  # method returns a hash containing the raw values plus the optional data
  # structure.  It intentionally does not mutate the return value of
  # fetch_collection so existing callers remain untouched.
  def fetch_collection_details(character_idx)
    resp = @http.get("#{BASE_URL}/api/website/armory/collection/#{character_idx}", headers: { 'Accept' => 'application/json' })
    parsed = parse_response(resp)
    {
      values: parsed['values'] || [],
      data: parsed['data'] || []
    }
  end

  private

  def parse_response(resp)
    body = resp.respond_to?(:body) ? resp.body : resp
    JSON.parse(body)
  rescue JSON::ParserError => e
    raise "Invalid JSON response: #{e.message}"
  end
end
