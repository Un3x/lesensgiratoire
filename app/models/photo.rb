require "zlib"
require "net/http"

class Photo < ApplicationRecord
  CADRAGE_TOLERANCE_DEG = 0
  DEMI_OUVERTURE_DEFAUT_DEG = 35
  CHAMP_PANORAMIQUE_DEG = 300
  INCLINAISON_DEFAUT_DEG = -12.0
  CHAMP_VUE_DEFAUT_DEG = 75.0
  PANORAMAX_API = "https://api.panoramax.xyz/api"
  MOISSON_RAYON_M = 60
  DATES_MAX_PAR_OUVRAGE = 6

  belongs_to :roundabout

  has_one_attached :image

  validate :illustration_presente
  validates :taken_on, presence: true,
    comparison: { less_than_or_equal_to: ->(_) { Date.current },
                  message: "ne peut pas être postérieure à la date du jour" }

  with_options if: :distante? do
    validates :author, presence: true
    validates :licence, presence: true
    validates :source_url, presence: true
    validates :taken_on, uniqueness: { scope: :roundabout_id,
      conditions: -> { where.not(image_url: nil) },
      message: "a déjà fait l'objet d'une observation distante pour cet ouvrage" }
  end

  normalizes :author, :licence, :source_url, :image_url, with: -> { it&.strip.presence }

  def self.releve_vierge
    { versees: 0, deja_versees: 0, hors_cadrage: 0, retirees: 0, sans_ouvrage: 0, injoignables: 0, refusees: [] }
  end

  def self.ingest_panoramax(path)
    fichier = Pathname.new(path)
    contenu = fichier.extname == ".gz" ? Zlib::GzipReader.open(fichier) { it.read } : fichier.read
    releve = releve_vierge

    contenu.each_line do |ligne|
      next if ligne.blank?
      verser(JSON.parse(ligne), releve)
    end

    releve
  end

  def self.moissonner_panoramax(roundabouts, releve = releve_vierge)
    roundabouts.each do |roundabout|
      clichés = interroger_panoramax(roundabout)
      next releve[:injoignables] += 1 if clichés.nil?

      moisson = retenus(clichés, roundabout)
      releve[:retirees] += perimees(roundabout, moisson.pluck("url")).destroy_all.size
      moisson.each { verser(it, releve) }
    end

    releve
  end

  def self.perimees(roundabout, adresses)
    distantes = where(roundabout: roundabout).where.not(image_url: nil)

    adresses.any? ? distantes.where.not(image_url: adresses) : distantes
  end

  def self.retenus(clichés, roundabout)
    clichés
      .filter_map { observation_panoramax(it, roundabout) }
      .reject { hors_cadrage?(it) }
      .group_by { it["date"] }
      .transform_values { |dujour| dujour.min_by { residuel(it) || Float::INFINITY } }
      .values
      .sort_by { it["date"] }
      .last(DATES_MAX_PAR_OUVRAGE)
  end

  def self.observation_panoramax(cliché, roundabout)
    lon, lat = cliché.dig("geometry", "coordinates")
    proprietes = cliché.fetch("properties", {})
    adresse = cliché.dig("assets", "sd", "href")
    return if adresse.blank? || lat.blank?

    rayon = roundabout.diameter_m.to_f / 2

    {
      "lat" => roundabout.lat.to_f,
      "lon" => roundabout.lon.to_f,
      "url" => adresse,
      "date" => proprietes["datetime"].to_s.first(10),
      "licence" => proprietes["license"],
      "auteur" => proprietes["geovisio:producer"],
      "source" => "#{PANORAMAX_API}/collections/#{proprietes["collection"]}/items/#{cliché["id"]}",
      "ecart_deg" => ecart_de_visee(lat, lon, proprietes["view:azimuth"], roundabout),
      "rapport" => rayon.positive? ? roundabout.distance_to(lat, lon) / rayon : nil,
      "champ_deg" => proprietes.dig("pers:interior_orientation", "field_of_view"),
      "cap_deg" => cap_vers(lat, lon, roundabout)
    }
  end

  def self.cap_vers(lat, lon, roundabout)
    nord = (roundabout.lat.to_f - lat) * 111_320.0
    est = (roundabout.lon.to_f - lon) * 111_320.0 * Math.cos(lat * Math::PI / 180)

    (Math.atan2(est, nord) * 180 / Math::PI) % 360
  end

  def self.ecart_de_visee(lat, lon, azimut, roundabout)
    return if azimut.blank?

    ecart = (cap_vers(lat, lon, roundabout) - azimut).abs % 360
    ecart > 180 ? 360 - ecart : ecart
  end

  def self.hors_cadrage?(observation)
    return false if observation["champ_deg"].to_f >= CHAMP_PANORAMIQUE_DEG

    residuel(observation).then { it.present? && it > CADRAGE_TOLERANCE_DEG }
  end

  def self.residuel(observation)
    ecart = observation["ecart_deg"]
    return if ecart.blank?

    ecart - demi_largeur_apparente(observation["rapport"])
  end

  def self.demi_largeur_apparente(rapport)
    return DEMI_OUVERTURE_DEFAUT_DEG if rapport.blank?
    return 90.0 if rapport <= 1

    Math.asin(1.0 / rapport) * 180 / Math::PI
  end

  def distante?
    image_url.present?
  end

  def reprojetable?
    heading.present?
  end

  def illustration
    distante? ? image_url : image
  end

  def self.verser(observation, releve)
    roundabout = Roundabout.matching_position(observation.fetch("lat"), observation.fetch("lon"))
    return releve[:sans_ouvrage] += 1 unless roundabout

    if hors_cadrage?(observation)
      releve[:hors_cadrage] += 1
      releve[:retirees] += 1 if find_by(roundabout: roundabout, image_url: observation.fetch("url"))&.destroy
      return releve
    end

    photo = find_or_initialize_by(roundabout: roundabout, image_url: observation.fetch("url"))
    photo.new_record? ? releve[:versees] += 1 : releve[:deja_versees] += 1
    photo.assign_attributes(
      taken_on: observation.fetch("date"),
      author: observation.fetch("auteur"),
      licence: observation.fetch("licence"),
      source_url: observation.fetch("source"),
      **reprojection(observation)
    )

    begin
      photo.save!
    rescue ActiveRecord::RecordInvalid => erreur
      photo.new_record? ? releve[:versees] -= 1 : releve[:deja_versees] -= 1
      releve[:refusees] << "#{observation["url"]} : #{erreur.record.errors.full_messages.to_sentence}"
    end

    releve
  end

  def self.reprojection(observation)
    return { heading: nil, pitch: nil, field_of_view: nil } unless panoramique?(observation)

    {
      heading: observation["cap_deg"],
      pitch: observation["inclinaison_deg"] || INCLINAISON_DEFAUT_DEG,
      field_of_view: observation["champ_vue_deg"] || CHAMP_VUE_DEFAUT_DEG
    }
  end

  def self.panoramique?(observation)
    observation["champ_deg"].to_f >= CHAMP_PANORAMIQUE_DEG && observation["cap_deg"].present?
  end

  def self.interroger_panoramax(roundabout, rayon_m: MOISSON_RAYON_M)
    lat = roundabout.lat.to_f
    lon = roundabout.lon.to_f
    dlat = rayon_m / 111_320.0
    dlon = dlat / Math.cos(lat * Math::PI / 180)
    emprise = [ lon - dlon, lat - dlat, lon + dlon, lat + dlat ].join(",")

    adresse = URI("#{PANORAMAX_API}/search?bbox=#{emprise}&limit=200")
    reponse = Net::HTTP.start(adresse.host, adresse.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do
      it.request(Net::HTTP::Get.new(adresse, "User-Agent" => "lesensgiratoire (recensement des ronds-points)"))
    end
    return unless reponse.is_a?(Net::HTTPSuccess)

    JSON.parse(reponse.body).fetch("features", [])
  rescue StandardError
    nil
  end

  private
    def illustration_presente
      return if image.attached? || distante?

      errors.add(:image, "doit être jointe ou référencée par une adresse distante")
    end
end
