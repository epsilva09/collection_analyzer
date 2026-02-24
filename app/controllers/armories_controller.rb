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
end
