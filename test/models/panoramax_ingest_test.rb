require "test_helper"

class PanoramaxIngestTest < ActiveSupport::TestCase
  setup do
    @roundabout = Roundabout.create!(lat: 44.837789, lon: -0.579180, diameter_m: 42.0, commune: "Bordeaux")
    @fichier = Rails.root.join("tmp/panoramax_test.jsonl")
  end

  teardown { File.delete(@fichier) if File.exist?(@fichier) }

  def ecrire(*observations)
    @fichier.write(observations.map(&:to_json).join("\n") + "\n")
  end

  def observation(**surcharges)
    {
      i: 0, lat: 44.837800, lon: -0.579200,
      url: "https://api.panoramax.xyz/images/abc/sd.jpg",
      thumb: "https://api.panoramax.xyz/images/abc/thumb.jpg",
      date: "2025-06-12", licence: "etalab-2.0", auteur: "Service départemental",
      source: "https://panoramax.ign.fr/#pic=abc", ecart_deg: 12.4, distance_m: 18.2
    }.merge(surcharges)
  end

  test "verse l'observation au dossier du rond-point le plus proche" do
    ecrire(observation)

    releve = Photo.ingest_panoramax(@fichier)

    assert_equal 1, releve[:versees]
    photo = @roundabout.photos.sole
    assert_equal Date.new(2025, 6, 12), photo.taken_on
    assert_equal "etalab-2.0", photo.licence
    assert_equal "Service départemental", photo.author
    assert_equal "https://panoramax.ign.fr/#pic=abc", photo.source_url
    assert photo.distante?
    assert_not photo.image.attached?
  end

  test "rejouer l'ingestion ne crée pas de doublon" do
    ecrire(observation)
    Photo.ingest_panoramax(@fichier)

    assert_no_difference -> { Photo.count } do
      releve = Photo.ingest_panoramax(@fichier)
      assert_equal 0, releve[:versees]
      assert_equal 1, releve[:deja_versees]
    end
  end

  test "une mention corrigée est reprise sans second versement" do
    ecrire(observation)
    Photo.ingest_panoramax(@fichier)
    ecrire(observation(licence: "CC-BY-SA-4.0"))

    assert_no_difference -> { Photo.count } do
      Photo.ingest_panoramax(@fichier)
    end
    assert_equal "CC-BY-SA-4.0", @roundabout.photos.sole.licence
  end

  test "deux clichés distincts du même ouvrage forment une timeline" do
    ecrire(observation, observation(url: "https://api.panoramax.xyz/images/def/sd.jpg", date: "2026-04-02"))

    Photo.ingest_panoramax(@fichier)

    assert_equal 2, @roundabout.photos.count
    assert_equal [ Date.new(2026, 4, 2), Date.new(2025, 6, 12) ], @roundabout.photos.map(&:taken_on)
  end

  test "une observation sans rond-point recensé à cette position est écartée" do
    ecrire(observation(lat: 48.85, lon: 2.35))

    releve = Photo.ingest_panoramax(@fichier)

    assert_equal 0, releve[:versees]
    assert_equal 1, releve[:sans_ouvrage]
    assert_equal 0, Photo.count
  end

  test "une observation sans attribution est refusée et signalée" do
    ecrire(observation(auteur: nil))

    releve = Photo.ingest_panoramax(@fichier)

    assert_equal 0, releve[:versees]
    assert_equal 1, releve[:refusees].size
    assert_equal 0, Photo.count
  end

  test "les lignes vides sont ignorées" do
    @fichier.write("\n#{observation.to_json}\n\n")

    assert_equal 1, Photo.ingest_panoramax(@fichier)[:versees]
  end
end
