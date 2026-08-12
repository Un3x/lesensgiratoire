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
      source: "https://panoramax.ign.fr/#pic=abc", ecart_deg: 12, distance_m: 18, rapport: 1.89
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

  test "une observation dont l'axe de visée manque l'ouvrage est écartée" do
    ecrire(observation(ecart_deg: 46, rapport: 1.96))

    releve = Photo.ingest_panoramax(@fichier)

    assert_equal 0, releve[:versees]
    assert_equal 1, releve[:hors_cadrage]
    assert_equal 0, Photo.count
  end

  test "un cliché pris au ras de l'anneau est retenu malgré un écart important" do
    ecrire(observation(ecart_deg: 38, rapport: 1.30))

    assert_equal 1, Photo.ingest_panoramax(@fichier)[:versees]
  end

  test "un cliché lointain est écarté pour un écart que la proximité aurait absous" do
    ecrire(observation(ecart_deg: 30, rapport: 4.0))

    assert_equal 1, Photo.ingest_panoramax(@fichier)[:hors_cadrage]
  end

  test "un objectif situé à l'intérieur de l'anneau est toujours retenu" do
    ecrire(observation(ecart_deg: 60, rapport: 0.9))

    assert_equal 1, Photo.ingest_panoramax(@fichier)[:versees]
  end

  test "l'axe tangent au bord de l'ouvrage est retenu" do
    ecrire(observation(ecart_deg: 30, rapport: 2.0))

    assert_equal 1, Photo.ingest_panoramax(@fichier)[:versees]
  end

  test "sans mesure de proximité, la demi-ouverture par défaut fait foi" do
    ecrire(observation(ecart_deg: 36, rapport: nil), observation(url: "https://x/b.jpg", ecart_deg: 35, rapport: nil))

    releve = Photo.ingest_panoramax(@fichier)

    assert_equal 1, releve[:hors_cadrage]
    assert_equal 1, releve[:versees]
  end

  test "une observation déjà versée est retirée si son cadrage devient irrecevable" do
    ecrire(observation)
    Photo.ingest_panoramax(@fichier)
    ecrire(observation(ecart_deg: 50, rapport: 2.0))

    releve = Photo.ingest_panoramax(@fichier)

    assert_equal 1, releve[:retirees]
    assert_equal 0, Photo.count
  end

  test "le retrait ne touche pas les observations versées à la main" do
    jointe = Photo.create!(roundabout: @roundabout, taken_on: Date.current,
      image: fixture_file_upload("observation.png", "image/png"))
    ecrire(observation(ecart_deg: 50, rapport: 2.0))

    Photo.ingest_panoramax(@fichier)

    assert_equal [ jointe ], @roundabout.photos.to_a
  end

  test "une observation sans mesure de cadrage est retenue" do
    ligne = observation
    ligne.delete(:ecart_deg)
    ecrire(ligne)

    assert_equal 1, Photo.ingest_panoramax(@fichier)[:versees]
  end

  test "les lignes vides sont ignorées" do
    @fichier.write("\n#{observation.to_json}\n\n")

    assert_equal 1, Photo.ingest_panoramax(@fichier)[:versees]
  end
end
