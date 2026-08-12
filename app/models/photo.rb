require "zlib"

class Photo < ApplicationRecord
  CADRAGE_TOLERANCE_DEG = 0
  DEMI_OUVERTURE_DEFAUT_DEG = 35

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
  end

  normalizes :author, :licence, :source_url, :image_url, with: -> { it&.strip.presence }

  def self.ingest_panoramax(path)
    fichier = Pathname.new(path)
    contenu = fichier.extname == ".gz" ? Zlib::GzipReader.open(fichier) { it.read } : fichier.read
    releve = { versees: 0, deja_versees: 0, hors_cadrage: 0, retirees: 0, sans_ouvrage: 0, refusees: [] }

    contenu.each_line do |ligne|
      next if ligne.blank?
      observation = JSON.parse(ligne)

      roundabout = Roundabout.matching_position(observation.fetch("lat"), observation.fetch("lon"))
      next releve[:sans_ouvrage] += 1 unless roundabout

      if hors_cadrage?(observation)
        releve[:hors_cadrage] += 1
        releve[:retirees] += 1 if find_by(roundabout: roundabout, image_url: observation.fetch("url"))&.destroy
        next
      end

      photo = find_or_initialize_by(roundabout: roundabout, image_url: observation.fetch("url"))
      photo.new_record? ? releve[:versees] += 1 : releve[:deja_versees] += 1
      photo.assign_attributes(
        taken_on: observation.fetch("date"),
        author: observation.fetch("auteur"),
        licence: observation.fetch("licence"),
        source_url: observation.fetch("source")
      )

      begin
        photo.save!
      rescue ActiveRecord::RecordInvalid => erreur
        photo.new_record? ? releve[:versees] -= 1 : releve[:deja_versees] -= 1
        releve[:refusees] << "#{observation["url"]} : #{erreur.record.errors.full_messages.to_sentence}"
      end
    end

    releve
  end

  def self.hors_cadrage?(observation)
    ecart = observation["ecart_deg"]
    return false if ecart.blank?

    ecart > demi_largeur_apparente(observation["rapport"]) + CADRAGE_TOLERANCE_DEG
  end

  def self.demi_largeur_apparente(rapport)
    return DEMI_OUVERTURE_DEFAUT_DEG if rapport.blank?
    return 90.0 if rapport <= 1

    Math.asin(1.0 / rapport) * 180 / Math::PI
  end

  def distante?
    image_url.present?
  end

  def illustration
    distante? ? image_url : image
  end

  private
    def illustration_presente
      return if image.attached? || distante?

      errors.add(:image, "doit être jointe ou référencée par une adresse distante")
    end
end
