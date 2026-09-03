class RoundaboutsController < ApplicationController
  MAX_MARKERS = 2_000
  FRANCE_BBOX = [ -5.5, 41.2, 9.8, 51.5 ].freeze

  def index
    respond_to do |format|
      format.html
      format.json { render json: recensement }
    end
  end

  def show
    @roundabout = Roundabout.find(params[:id])
    @photo = Photo.new(roundabout: @roundabout, taken_on: Date.current)
  end

  private
    def recensement
      scope = Roundabout.at_least(min_diameter).within(*bbox)
      scope = scope.public_send(params[:junction_type]) if Roundabout.junction_types.key?(params[:junction_type])
      total = scope.count
      points = scope.echantillon(MAX_MARKERS)
        .pluck(:id, :lat, :lon, :diameter_m, :name, :commune)

      {
        total: total,
        sampled: total > MAX_MARKERS,
        limit: MAX_MARKERS,
        roundabouts: points.map { |id, lat, lon, diameter, name, commune|
          { id: id, lat: lat.to_f, lon: lon.to_f, d: diameter&.to_f, name: name, commune: commune }
        }
      }
    end

    def bbox
      values = params[:bbox].to_s.split(",").map { Float(it, exception: false) }
      return FRANCE_BBOX unless values.size == 4 && values.all?

      west, south, east, north = values
      [ west.clamp(-180, 180), south.clamp(-90, 90), east.clamp(-180, 180), north.clamp(-90, 90) ]
    end

    def min_diameter
      Float(params[:min_diameter], exception: false)&.clamp(0, 1_000) || Roundabout::DEFAULT_MIN_DIAMETER_M
    end
end
