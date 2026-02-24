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

      set_a = @result[:values_a].to_set
      set_b = @result[:values_b].to_set

      @result[:common] = (set_a & set_b).to_a.sort
      @result[:only_a] = (set_a - set_b).to_a.sort
      @result[:only_b] = (set_b - set_a).to_a.sort
    rescue StandardError => e
      @error = e.message
    end

    respond_to do |format|
      format.html
      format.json { render json: { result: @result, error: @error } }
    end
  end
end
