class Roundabout < ApplicationRecord
  MATCH_RADIUS_M = 70
  DEFAULT_MIN_DIAMETER_M = 20

  has_many :photos, -> { order(taken_on: :desc, id: :desc) }, dependent: :destroy
  has_many :votes, dependent: :destroy

  validates :lat, :lon, presence: true
  validates :lat, numericality: { in: -90..90 }
  validates :lon, numericality: { in: -180..180 }

  normalizes :name, with: -> { it&.strip.presence }

  scope :at_least, ->(diameter) { where(diameter_m: diameter..) }
  scope :within, ->(west, south, east, north) {
    where(lat: south..north).where(lon: west..east)
  }
  scope :around, ->(lat, lon, radius_m = MATCH_RADIUS_M) {
    lat_delta = radius_m / 111_320.0
    lon_delta = lat_delta / Math.cos(lat * Math::PI / 180)
    where(lat: (lat - lat_delta)..(lat + lat_delta), lon: (lon - lon_delta)..(lon + lon_delta))
  }

  def self.matching_position(lat, lon)
    around(lat, lon)
      .select { it.distance_to(lat, lon) <= MATCH_RADIUS_M }
      .min_by { it.distance_to(lat, lon) }
  end

  def distance_to(other_lat, other_lon)
    lat_m = (other_lat - lat.to_f) * 111_320.0
    lon_m = (other_lon - lon.to_f) * 111_320.0 * Math.cos(lat.to_f * Math::PI / 180)
    Math.sqrt(lat_m**2 + lon_m**2)
  end

  def designation
    name.presence || "Rond-point sans nom"
  end

  def coordinates
    format("%.6f %s, %.6f %s",
      lat.abs, lat.negative? ? "S" : "N",
      lon.abs, lon.negative? ? "O" : "E").tr(".", ",")
  end

  def display_zoom(pixels = 420, marge = 2.2)
    etendue = (diameter_m || DEFAULT_MIN_DIAMETER_M).to_f * marge
    Math.log2(156_543.03 * Math.cos(lat.to_f * Math::PI / 180) * pixels / etendue).floor.clamp(15, 20)
  end

  def appreciations(year)
    votes.for_year(year).group(:liked).count
  end
end
