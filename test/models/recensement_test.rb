require "test_helper"

class RecensementTest < ActiveSupport::TestCase
  BORDEAUX = { "lat" => 44.837789, "lon" => -0.579180, "diameter_m" => 42.0, "name" => nil,
    "osm_way_ids" => [ 1 ], "commune" => "Bordeaux", "insee_code" => "33063",
    "departement" => "Gironde", "region" => "Nouvelle-Aquitaine" }.freeze

  SANS_GEOCODAGE = ->(_lat, _lon) { nil }

  def anneau(id, lat, lon, rayon_m: 20, tags: { "junction" => "circular" })
    lat_delta = rayon_m / 111_320.0
    lon_delta = lat_delta / Math.cos(lat * Math::PI / 180)
    sommets = 12.times.map { |i|
      angle = i * Math::PI / 6
      { "lat" => (lat + lat_delta * Math.sin(angle)).round(7), "lon" => (lon + lon_delta * Math.cos(angle)).round(7) }
    }
    { "id" => id, "tags" => tags, "geometry" => sommets + [ sommets.first ] }
  end

  def decale(lat, metres) = lat + metres / 111_320.0

  test "deux arcs circulaires à trente mètres d'un ouvrage d'un seul way le font basculer sans le déplacer" do
    arcs = [ anneau(2, decale(44.837789, 30), -0.579180), anneau(3, decale(44.837789, -30), -0.579180) ]

    releve = Roundabout.enrichir_recensement([ BORDEAUX ], arcs, &SANS_GEOCODAGE)

    assert_equal 1, releve.size
    assert_equal "circular", releve.first["junction_type"]
    assert_equal [ 1, 2, 3 ], releve.first["osm_way_ids"]
    assert_equal 44.837789, releve.first["lat"]
    assert_equal 42.0, releve.first["diameter_m"]
  end

  test "à égalité de ways, l'ouvrage reste à l'anneau" do
    releve = Roundabout.enrichir_recensement([ BORDEAUX ], [ anneau(2, decale(44.837789, 30), -0.579180) ], &SANS_GEOCODAGE)

    assert_equal "roundabout", releve.first["junction_type"]
    assert_equal [ 1, 2 ], releve.first["osm_way_ids"]
  end

  test "deux arcs circulaires isolés à quarante mètres l'un de l'autre forment un ouvrage nouveau mesuré et géocodé" do
    geocodage = ->(lat, lon) {
      assert_in_delta 48.8738, lat, 0.001
      { "commune" => "Paris", "insee_code" => "75116", "departement" => "Paris", "region" => "Île-de-France" }
    }

    releve = Roundabout.enrichir_recensement([ BORDEAUX ],
      [ anneau(10, 48.8738, 2.2950, rayon_m: 60), anneau(11, decale(48.8738, 40), 2.2950, rayon_m: 60) ], &geocodage)

    assert_equal 2, releve.size
    nouveau = releve.last
    assert_equal "circular", nouveau["junction_type"]
    assert_equal [ 10, 11 ], nouveau["osm_way_ids"]
    assert_in_delta 48.8738 + 20 / 111_320.0, nouveau["lat"], 0.00001
    assert_in_delta 120.0, nouveau["diameter_m"], 10
    assert_equal "Paris", nouveau["commune"]
    assert_equal "Île-de-France", nouveau["region"]
  end

  test "un ouvrage nouveau ne retient qu'un nom de lieu" do
    voie = anneau(10, 48.0, 2.0, tags: { "junction" => "circular", "name" => "Rue du Jard" })
    lieu = anneau(11, 47.0, 2.0, tags: { "junction" => "circular", "name" => "Place de la Nation" })

    releve = Roundabout.enrichir_recensement([], [ voie, lieu ], &SANS_GEOCODAGE)

    assert_nil releve.first["name"]
    assert_equal "Place de la Nation", releve.last["name"]
    assert_nil releve.last["commune"]
  end

  test "le chargement réapparie par position et met à jour le régime de priorité" do
    existant = Roundabout.create!(lat: 44.837789, lon: -0.579180, diameter_m: 42.0)
    fichier = Rails.root.join("tmp/recensement_test.json")
    fichier.write(JSON.generate([
      BORDEAUX.merge("lat" => 44.838089, "junction_type" => "circular"),
      { "lat" => 48.873778, "lon" => 2.295036, "diameter_m" => 137.6, "name" => "Place Charles de Gaulle", "osm_way_ids" => [ 4 ], "junction_type" => "circular" }
    ]))

    releve = Roundabout.charger_recensement(fichier)

    assert_equal({ inscrits: 1, mis_a_jour: 1 }, releve)
    assert existant.reload.circular?
    assert_equal 44.837789, existant.lat.to_f
    assert_equal "Bordeaux", existant.commune
    assert Roundabout.find_by(name: "Place Charles de Gaulle").circular?
  ensure
    fichier&.delete
  end

  test "tout enregistrement sort avec un régime de priorité" do
    releve = Roundabout.enrichir_recensement([ BORDEAUX ], [], &SANS_GEOCODAGE)

    assert_equal [ "roundabout" ], releve.map { it["junction_type"] }
  end
end
