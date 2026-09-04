require "test_helper"

class CommonsTest < ActiveSupport::TestCase
  setup do
    @roundabout = Roundabout.create!(lat: 48.827300, lon: 2.352700, diameter_m: 60.0, osm_way_ids: [ 11288145, 320648523 ])
  end

  def page(date: "2021-01-21 12:30:00", artist: "<a href=\"//commons.wikimedia.org/wiki/User:Chabe01\" title=\"User:Chabe01\">Chabe01</a>")
    metadonnees = { "Artist" => { "value" => artist }, "LicenseShortName" => { "value" => "CC BY-SA 4.0" } }
    metadonnees["DateTimeOriginal"] = { "value" => date } if date

    {
      "title" => "File:Place.jpg",
      "imageinfo" => [ {
        "thumburl" => "https://upload.wikimedia.org/wikipedia/commons/thumb/1/17/Place.jpg/1024px-Place.jpg",
        "descriptionurl" => "https://commons.wikimedia.org/wiki/File:Place.jpg",
        "extmetadata" => metadonnees
      } ]
    }
  end

  test "une image Commons devient une observation distante attribuée, datée et reliée à sa page" do
    observation = Photo.observation_commons(page, @roundabout)

    assert_equal "https://upload.wikimedia.org/wikipedia/commons/thumb/1/17/Place.jpg/1024px-Place.jpg", observation["url"]
    assert_equal "Chabe01", observation["auteur"]
    assert_equal "CC BY-SA 4.0", observation["licence"]
    assert_equal "2021-01-21", observation["date"]
    assert_equal "https://commons.wikimedia.org/wiki/File:Place.jpg", observation["source"]
    assert_equal @roundabout.lat.to_f, observation["lat"]
  end

  test "une image Commons sans date de prise de vue n'est pas versée" do
    assert_nil Photo.observation_commons(page(date: nil), @roundabout)
    assert_nil Photo.observation_commons(page(date: "vers 1900"), @roundabout)
  end

  test "l'illustration relie le tag wikidata des ways à l'image P18 puis à Commons" do
    reponses = {
      /openstreetmap\.org.*ways=11288145,320648523/ => { "elements" => [ { "id" => 320648523, "tags" => { "wikidata" => "Q3390281" } } ] },
      /wikidata\.org.*ids=Q3390281/ => { "entities" => { "Q3390281" => { "claims" => { "P18" => [ { "mainsnak" => { "datavalue" => { "value" => "Place.jpg" } } } ] } } } },
      /commons\.wikimedia\.org.*titles=File%3APlace\.jpg/ => { "query" => { "pages" => { "1" => page } } }
    }
    lire = ->(adresse) { reponses.find { |motif, _| adresse.to_s.match?(motif) }&.last or flunk("adresse imprévue : #{adresse}") }

    releve = avec_lecture_distante(lire) { Photo.illustrer_depuis_commons([ @roundabout ]) }

    assert_equal 1, releve[:versees]
    assert_equal "https://commons.wikimedia.org/wiki/File:Place.jpg", @roundabout.photos.sole.source_url
  end

  test "un ouvrage sans tag wikidata reste sans illustration Commons" do
    lire = ->(_) { { "elements" => [ { "id" => 11288145, "tags" => { "name" => "Place" } } ] } }

    releve = avec_lecture_distante(lire) { Photo.illustrer_depuis_commons([ @roundabout ]) }

    assert_equal 0, releve[:versees]
    assert_empty @roundabout.photos
  end

  test "une source injoignable est comptée sans interrompre l'illustration" do
    releve = avec_lecture_distante(->(_) { nil }) { Photo.illustrer_depuis_commons([ @roundabout ]) }

    assert_equal 1, releve[:injoignables]
  end
end
