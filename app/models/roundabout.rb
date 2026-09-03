require "net/http"
require "zlib"

class Roundabout < ApplicationRecord
  MATCH_RADIUS_M = 70
  DEFAULT_MIN_DIAMETER_M = 20
  NOM_DE_LIEU = /\A(rond[- ]?point|giratoire|place|carrefour|esplanade)\b/i
  OVERPASS_MIRRORS = %w[https://overpass-api.de https://overpass.kumi.systems https://overpass.private.coffee].freeze
  BAN_API = "https://api-adresse.data.gouv.fr/reverse/"
  RECENSEMENT_ATTRIBUTES = %w[diameter_m name osm_way_ids commune insee_code departement region junction_type].freeze

  has_many :photos, -> { order(taken_on: :desc, id: :desc) }, dependent: :destroy
  has_many :votes, dependent: :destroy

  validates :lat, :lon, presence: true
  validates :lat, numericality: { in: -90..90 }
  validates :lon, numericality: { in: -180..180 }

  enum :junction_type, { roundabout: "roundabout", circular: "circular" }

  normalizes :name, with: -> { it&.strip.presence }

  scope :at_least, ->(diameter) { where(diameter_m: diameter..) }
  scope :within, ->(west, south, east, north) {
    where(lat: south..north).where(lon: west..east)
  }
  scope :echantillon, ->(combien) { order(:sample_key).limit(combien) }
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

  def self.charger_recensement(file)
    file = Pathname(file)
    contenu = file.extname == ".gz" ? Zlib::GzipReader.open(file) { it.read } : file.read
    releve = { inscrits: 0, mis_a_jour: 0 }

    JSON.parse(contenu).each do |record|
      roundabout = matching_position(record.fetch("lat"), record.fetch("lon")) || new(record.slice("lat", "lon"))
      releve[roundabout.new_record? ? :inscrits : :mis_a_jour] += 1
      roundabout.update!(record.slice(*RECENSEMENT_ATTRIBUTES))
    end

    releve
  end

  def self.distance_m(lat, lon, other_lat, other_lon)
    lat_m = (other_lat - lat) * 111_320.0
    lon_m = (other_lon - lon) * 111_320.0 * Math.cos(lat * Math::PI / 180)
    Math.sqrt(lat_m**2 + lon_m**2)
  end

  def self.enrichir_recensement(records, ways, &geocoder)
    records = records.map { it.merge("junction_type" => it.fetch("junction_type", "roundabout"), "osm_way_ids" => it["osm_way_ids"].dup) }
    carreaux = records.each_with_index.group_by { |record, _| carreau(record["lat"], record["lon"]) }
    rattaches = Hash.new { |h, k| h[k] = [] }
    orphelins = []

    ways.each do |way|
      centre = centroide(way["geometry"])
      voisin = carreaux_autour(*centre).flat_map { carreaux.fetch(it, []) }
        .map { |record, index| [ distance_m(*centre, record["lat"], record["lon"]), index ] }
        .select { |distance, _| distance <= MATCH_RADIUS_M }.min_by(&:first)
      voisin ? rattaches[voisin.last] << way : orphelins << way
    end

    rattaches.each do |index, ways_rattaches|
      record = records[index]
      record["osm_way_ids"] += ways_rattaches.map { it["id"] }
      record["junction_type"] = regime_majoritaire(ways_rattaches, record["osm_way_ids"].size - ways_rattaches.size)
    end

    records + grappes(orphelins).map { ouvrage(it, &geocoder) }
  end

  def self.grappes(ways)
    centres = ways.map { centroide(it["geometry"]) }
    parents = (0...ways.size).to_a
    racine = ->(i) { parents[i] == i ? i : (parents[i] = racine.(parents[i])) }
    carreaux = (0...ways.size).group_by { carreau(*centres[it]) }

    ways.each_index do |i|
      carreaux_autour(*centres[i]).flat_map { carreaux.fetch(it, []) }.each do |j|
        parents[racine.(i)] = racine.(j) if j > i && distance_m(*centres[i], *centres[j]) <= MATCH_RADIUS_M
      end
    end

    ways.each_index.group_by { racine.(it) }.values.map { it.map { |i| ways[i] } }
  end

  def self.ouvrage(ways, &geocoder)
    sommets = ways.flat_map { it["geometry"] }
    lat, lon = centroide(sommets)
    diametre = 2 * sommets.sum { distance_m(lat, lon, it["lat"], it["lon"]) } / sommets.size
    adresse = geocoder&.call(lat, lon) || {}

    {
      "lat" => lat.round(6), "lon" => lon.round(6), "diameter_m" => diametre.round(1),
      "name" => ways.filter_map { it.dig("tags", "name") }.find { it.match?(NOM_DE_LIEU) },
      "osm_way_ids" => ways.map { it["id"] },
      "commune" => adresse["commune"], "insee_code" => adresse["insee_code"],
      "departement" => adresse["departement"], "region" => adresse["region"],
      "junction_type" => regime_majoritaire(ways, 0)
    }
  end

  def self.regime_majoritaire(ways, anneaux_connus)
    circulaires = ways.count { it.dig("tags", "junction") == "circular" }
    circulaires > ways.size - circulaires + anneaux_connus ? "circular" : "roundabout"
  end

  def self.centroide(sommets)
    sommets = sommets[0...-1] if sommets.size > 1 && sommets.first == sommets.last
    [ sommets.sum { it["lat"] } / sommets.size, sommets.sum { it["lon"] } / sommets.size ]
  end

  def self.carreau(lat, lon) = [ (lat * 1000).floor, (lon * 1000).floor ]

  def self.carreaux_autour(lat, lon)
    x, y = carreau(lat, lon)
    (-1..1).flat_map { |dx| (-1..1).map { |dy| [ x + dx, y + dy ] } }
  end

  def self.ways_circulaires
    requete = "[out:json][timeout:180];area[\"ISO3166-1\"=\"FR\"]->.fr;way[\"junction\"=\"circular\"](area.fr);out geom;"
    OVERPASS_MIRRORS.cycle.first(9).each do |miroir|
      reponse = Net::HTTP.post_form(URI("#{miroir}/api/interpreter"), "data" => requete)
      return JSON.parse(reponse.body).fetch("elements").select { it["geometry"] } if reponse.is_a?(Net::HTTPSuccess)

      sleep 15
    end

    raise "Aucun miroir Overpass n'a répondu"
  end

  def self.adresse_ban(lat, lon)
    proprietes = 2.times.lazy.map {
      reponse = Net::HTTP.get_response(URI("#{BAN_API}?lat=#{lat}&lon=#{lon}"))
      JSON.parse(reponse.body).dig("features", 0, "properties") if reponse.is_a?(Net::HTTPSuccess)
    }.find(&:itself) or return

    _numero, departement, region = proprietes["context"].to_s.split(", ")
    { "commune" => proprietes["city"], "insee_code" => proprietes["citycode"], "departement" => departement, "region" => region }
  end

  def distance_to(other_lat, other_lon)
    self.class.distance_m(lat.to_f, lon.to_f, other_lat, other_lon)
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
