require "test_helper"

class PanoramaxMoissonTest < ActiveSupport::TestCase
  setup do
    @roundabout = Roundabout.create!(lat: 44.800000, lon: -0.600000, diameter_m: 40.0, commune: "Bordeaux")
  end

  def cliché(lat:, lon:, azimut:, date: "2025-06-12", champ: 90, id: "abc", licence: "etalab-2.0")
    {
      "id" => id,
      "geometry" => { "coordinates" => [ lon, lat ] },
      "assets" => { "sd" => { "href" => "https://panoramax.test/#{id}/sd.jpg" } },
      "properties" => {
        "datetime" => "#{date}T10:00:00+00:00",
        "license" => licence,
        "geovisio:producer" => "Service départemental",
        "collection" => "col-1",
        "view:azimuth" => azimut,
        "pers:interior_orientation" => { "field_of_view" => champ }
      }
    }
  end

  test "l'écart de visée est nul quand l'objectif pointe sur l'ouvrage" do
    au_sud = 44.799100

    assert_in_delta 0, Photo.ecart_de_visee(au_sud, -0.600000, 0, @roundabout), 0.5
  end

  test "l'écart de visée vaut cent quatre-vingts degrés quand l'objectif tourne le dos" do
    au_sud = 44.799100

    assert_in_delta 180, Photo.ecart_de_visee(au_sud, -0.600000, 180, @roundabout), 0.5
  end

  test "l'écart de visée se replie sur le plus court arc" do
    au_sud = 44.799100

    assert_in_delta 90, Photo.ecart_de_visee(au_sud, -0.600000, 270, @roundabout), 0.5
  end

  test "une prise de vue panoramique échappe au critère de cadrage" do
    panoramique = { "ecart_deg" => 170, "rapport" => 3.0, "champ_deg" => 360 }

    assert_not Photo.hors_cadrage?(panoramique)
  end

  test "une prise de vue à champ ordinaire reste soumise au critère" do
    ordinaire = { "ecart_deg" => 170, "rapport" => 3.0, "champ_deg" => 90 }

    assert Photo.hors_cadrage?(ordinaire)
  end

  test "la moisson retient un cliché par date" do
    clichés = [
      cliché(lat: 44.799100, lon: -0.600000, azimut: 0, id: "a"),
      cliché(lat: 44.799100, lon: -0.600000, azimut: 5, id: "b"),
      cliché(lat: 44.799100, lon: -0.600000, azimut: 0, date: "2026-04-02", id: "c")
    ]

    retenus = Photo.retenus(clichés, @roundabout)

    assert_equal %w[2025-06-12 2026-04-02], retenus.map { it["date"] }.sort
  end

  test "à date égale, le cliché le mieux aligné l'emporte" do
    clichés = [
      cliché(lat: 44.799100, lon: -0.600000, azimut: 25, id: "de-biais"),
      cliché(lat: 44.799100, lon: -0.600000, azimut: 0, id: "de-face")
    ]

    assert_equal "https://panoramax.test/de-face/sd.jpg", Photo.retenus(clichés, @roundabout).sole["url"]
  end

  test "les clichés qui manquent l'ouvrage ne sont pas moissonnés" do
    clichés = [ cliché(lat: 44.799100, lon: -0.600000, azimut: 180, id: "dos-tourne") ]

    assert_empty Photo.retenus(clichés, @roundabout)
  end

  test "la timeline d'un ouvrage est bornée aux dates les plus récentes" do
    clichés = (1..9).map { cliché(lat: 44.799100, lon: -0.600000, azimut: 0, date: "20#{10 + it}-05-01", id: "c#{it}") }

    retenus = Photo.retenus(clichés, @roundabout)

    assert_equal Photo::DATES_MAX_PAR_OUVRAGE, retenus.size
    assert_equal "2019-05-01", retenus.last["date"]
  end

  test "une observation moissonnée porte son attribution et sa source" do
    observation = Photo.observation_panoramax(cliché(lat: 44.799100, lon: -0.600000, azimut: 0), @roundabout)

    assert_equal "Service départemental", observation["auteur"]
    assert_equal "etalab-2.0", observation["licence"]
    assert_equal "#{Photo::PANORAMAX_API}/collections/col-1/items/abc", observation["source"]
    assert_in_delta 5.0, observation["rapport"], 0.5
  end

  test "la moisson évince les observations distantes qu'elle ne retient plus" do
    ancienne = Photo.create!(roundabout: @roundabout, taken_on: "2019-01-01", author: "x", licence: "y",
      source_url: "https://s", image_url: "https://panoramax.test/ancienne/sd.jpg")

    perimees = Photo.perimees(@roundabout, [ "https://panoramax.test/abc/sd.jpg" ])

    assert_includes perimees, ancienne
  end

  test "une moisson vide évince toutes les observations distantes de l'ouvrage" do
    Photo.create!(roundabout: @roundabout, taken_on: "2019-01-01", author: "x", licence: "y",
      source_url: "https://s", image_url: "https://panoramax.test/ancienne/sd.jpg")

    assert_equal 1, Photo.perimees(@roundabout, []).count
  end

  test "l'éviction épargne les observations versées à la main" do
    jointe = Photo.create!(roundabout: @roundabout, taken_on: Date.current,
      image: fixture_file_upload("observation.png", "image/png"))

    assert_not_includes Photo.perimees(@roundabout, [ "https://panoramax.test/abc/sd.jpg" ]), jointe
  end

  test "un ouvrage ne porte qu'une observation distante par date" do
    Photo.create!(roundabout: @roundabout, taken_on: "2025-06-12", author: "x", licence: "y",
      source_url: "https://s", image_url: "https://panoramax.test/premiere/sd.jpg")
    doublon = Photo.new(roundabout: @roundabout, taken_on: "2025-06-12", author: "x", licence: "y",
      source_url: "https://s", image_url: "https://panoramax.test/seconde/sd.jpg")

    assert_not doublon.valid?
    assert_includes doublon.errors.attribute_names, :taken_on
  end

  test "une observation jointe n'interdit pas une observation distante du même jour" do
    Photo.create!(roundabout: @roundabout, taken_on: "2025-06-12",
      image: fixture_file_upload("observation.png", "image/png"))

    distante = Photo.new(roundabout: @roundabout, taken_on: "2025-06-12", author: "x", licence: "y",
      source_url: "https://s", image_url: "https://panoramax.test/seconde/sd.jpg")

    assert distante.valid?
  end

  test "la moisson verse les clichés retenus au dossier" do
    releve = Photo.releve_vierge
    Photo.retenus([ cliché(lat: 44.799100, lon: -0.600000, azimut: 0) ], @roundabout).each { Photo.verser(it, releve) }

    assert_equal 1, releve[:versees]
    assert_equal "https://panoramax.test/abc/sd.jpg", @roundabout.photos.sole.image_url
  end
end
