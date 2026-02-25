class ArmoriesController < ApplicationController
  def index
    @name = params[:name].presence || 'Cadamantis'
    client = ArmoryClient.new
    @error = nil
    @character_idx = nil
    @values = []

    begin
      @character_idx = client.fetch_character_idx(@name)
      if @character_idx
        @values = client.fetch_collection(@character_idx).map(&:to_s).map(&:strip)
      else
        @error = "characterIdx not found for #{@name}"
      end
    rescue StandardError => e
      @error = e.message
    end

    # If we have values, normalize and prioritize special attributes for the index view
    if @values.present?
      annotated = @values.map { |v| annotate_value(v) }

      special_rows = annotated.select { |r| r[:is_special] }
      special_rows.sort_by! do |r|
        idx = special_attributes.find_index { |s| r[:parsed_key] == s }
        idx || special_attributes.length
      end

      regular_rows = annotated.reject { |r| r[:is_special] }

      @special_values = special_rows.map { |r| r[:raw] }
      @regular_values = regular_rows.map { |r| r[:raw] }
    else
      @special_values = []
      @regular_values = []
    end

    respond_to do |format|
      format.html
      format.json { render json: { name: @name, character_idx: @character_idx, values: @values, error: @error, special_values: @special_values, regular_values: @regular_values } }
    end
  end

  # Compare collections of two characters by name.
  # Expects params[:name_a] and params[:name_b]
  def compare
    name_a = params[:name_a].presence
    name_b = params[:name_b].presence

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
      # Annotate rows with a cleaned attribute and is_special flag, then order using shared helpers
      annotated = detailed.map do |row|
        meta = annotate_value(row[:attribute])
        row.merge(cleaned_attribute: meta[:cleaned], parsed_key: meta[:parsed_key], is_special: meta[:is_special], had_ignore_prefix: meta[:had_ignore_prefix])
      end

      special_rows = annotated.select { |r| r[:is_special] }
      # Sort special rows according to the shared special_attributes order
      special_rows.sort_by! do |r|
        idx = special_attributes.find_index { |s| r[:parsed_key] == s }
        idx || special_attributes.length
      end

      regular_rows = annotated.reject { |r| r[:is_special] }

      @result[:detailed_ordered] = special_rows + regular_rows
      @result[:common] = (parsed_a.keys & parsed_b.keys).to_a.sort
      @result[:only_a] = (parsed_a.keys - parsed_b.keys).to_a.sort
      @result[:only_b] = (parsed_b.keys - parsed_a.keys).to_a.sort

      # Provide annotated versions for use in the view (preserve original strings)
      @result[:common_annotated] = @result[:common].map { |item| annotate_value(item) }
      @result[:only_a_annotated] = @result[:only_a].map { |item| annotate_value(item) }
      @result[:only_b_annotated] = @result[:only_b].map { |item| annotate_value(item) }
    rescue StandardError => e
      @error = e.message
    end

    respond_to do |format|
      format.html
      format.json { render json: { result: @result, error: @error } }
    end
  end

  private

  def special_attributes
    [
      "Perfuração",
      "PVE Perfuração",
      "Danos Críticos",
      "PVE Dano Crítico",
      "Aumentou todas as técnicas Amp.",
      "PVE Todas as Técnicas Amp",
      "Aumentou todos os ataques",
      "PVE Todos os Ataques"
    ]
  end

  def prefix_regex
    /\A\s*(PVE\s+)?Ignorar\s+/i
  end

  def annotate_value(raw)
    original = raw.to_s.strip
    had_ignore = !!(original =~ prefix_regex)
    cleaned = had_ignore ? original.sub(prefix_regex, '').strip : original

    parsed = AttributeParser.parse([cleaned]) rescue {}
    parsed_key = parsed.keys.first.to_s rescue cleaned

    is_special = false
    is_special = special_attributes.include?(parsed_key) unless had_ignore

    { raw: raw, cleaned: cleaned, parsed_key: parsed_key, is_special: is_special, had_ignore_prefix: had_ignore }
  end
end
