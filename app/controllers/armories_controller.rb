class ArmoriesController < ApplicationController
  def index
    @name = params[:name].presence || 'Popov'
    client = ArmoryClient.new
    @error = nil
    @character_idx = nil
    @values = []

    begin
      @character_idx = client.fetch_character_idx(@name)
      if @character_idx
        @values = client.fetch_collection(@character_idx)
      else
        @error = "characterIdx not found for #{@name}"
      end
    rescue StandardError => e
      @error = e.message
    end

    respond_to do |format|
      format.html
      format.json { render json: { name: @name, character_idx: @character_idx, values: @values, error: @error } }
    end
  end

  # Compare collections of two characters by name.
  # Expects params[:name_a] and params[:name_b]
  def compare
    name_a = params[:name_a].presence || params[:name].presence || 'Cadamantis'
    name_b = params[:name_b].presence || 'Cadamantis2'

    client = ArmoryClient.new
    @error = nil
    @result = {
      name_a: name_a,
      name_b: name_b,
      character_idx_a: nil,
      character_idx_b: nil,
      values_a: [],
      values_b: [],
      common: [],
      only_a: [],
      only_b: []
    }

    begin
      @result[:character_idx_a] = client.fetch_character_idx(name_a)
      @result[:character_idx_b] = client.fetch_character_idx(name_b)

      if @result[:character_idx_a]
        @result[:values_a] = client.fetch_collection(@result[:character_idx_a]).map(&:to_s).map(&:strip)
      end

      if @result[:character_idx_b]
        @result[:values_b] = client.fetch_collection(@result[:character_idx_b]).map(&:to_s).map(&:strip)
      end

      # Parse attributes into structured numeric values
      parsed_a = AttributeParser.parse(@result[:values_a])
      parsed_b = AttributeParser.parse(@result[:values_b])

      keys = (parsed_a.keys | parsed_b.keys).to_a.sort

      detailed = keys.map do |k|
        a = parsed_a[k] || { value: 0.0, unit: nil, raw: nil }
        b = parsed_b[k] || { value: 0.0, unit: nil, raw: nil }
        unit = (a[:unit] == b[:unit]) ? a[:unit] || b[:unit] : :mixed
        val_a = a[:value] || 0.0
        val_b = b[:value] || 0.0
        diff = (val_a - val_b)
        { attribute: k, value_a: val_a, value_b: val_b, unit: unit, diff: diff, raw_a: a[:raw], raw_b: b[:raw] }
      end

      @result[:detailed] = detailed
      @result[:common] = (parsed_a.keys & parsed_b.keys).to_a.sort
      @result[:only_a] = (parsed_a.keys - parsed_b.keys).to_a.sort
      @result[:only_b] = (parsed_b.keys - parsed_a.keys).to_a.sort
    rescue StandardError => e
      @error = e.message
    end

    respond_to do |format|
      format.html
      format.json { render json: { result: @result, error: @error } }
    end
  end
end
