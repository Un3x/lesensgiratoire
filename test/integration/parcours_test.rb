require "test_helper"

class ParcoursTest < ActionDispatch::IntegrationTest
  setup do
    @roundabout = Roundabout.create!(lat: 44.837789, lon: -0.579180, diameter_m: 42.0,
      commune: "Bordeaux", departement: "Gironde", region: "Nouvelle-Aquitaine")
    @raquette = Roundabout.create!(lat: 44.840000, lon: -0.580000, diameter_m: 8.0, commune: "Bordeaux")
  end

  test "la carte n'expose que les ouvrages de l'emprise atteignant le seuil de diamètre" do
    get roundabouts_path(format: :json, bbox: "-1.0,44.5,0.0,45.0")
    releve = response.parsed_body

    assert_response :success
    assert_equal [ @roundabout.id ], releve["roundabouts"].map { it["id"] }
    assert_equal 1, releve["total"]
    assert_not releve["truncated"]
  end

  test "le seuil de diamètre est réglable par le consultant" do
    get roundabouts_path(format: :json, bbox: "-1.0,44.5,0.0,45.0", min_diameter: 5)

    assert_equal 2, response.parsed_body["total"]
  end

  test "une emprise hors de France ne renvoie aucun ouvrage" do
    get roundabouts_path(format: :json, bbox: "10.0,50.0,11.0,51.0")

    assert_equal 0, response.parsed_body["total"]
  end

  test "de la carte à la fiche puis au suffrage jusqu'au palmarès" do
    get root_path
    assert_response :success

    get roundabout_path(@roundabout)
    assert_response :success
    assert_select "h1", /Rond-point sans nom/

    assert_difference -> { Vote.count }, 1 do
      post roundabout_votes_path(@roundabout, category: "plus_moche")
    end
    assert_redirected_to @roundabout

    assert_no_difference -> { Vote.count } do
      post roundabout_votes_path(@roundabout, category: "plus_moche")
    end

    get palmares_path(year: Date.current.year)
    assert_response :success
    assert_select ".classement td", text: "Rond-point sans nom"
  end

  test "une observation datée est versée au dossier" do
    assert_difference -> { @roundabout.photos.count }, 1 do
      post roundabout_photos_path(@roundabout), params: {
        photo: { image: fixture_file_upload("observation.png", "image/png"), taken_on: "2026-07-14" }
      }
    end
    assert_redirected_to @roundabout
  end

  test "une observation sans date est refusée sans quitter la fiche" do
    assert_no_difference -> { @roundabout.photos.count } do
      post roundabout_photos_path(@roundabout), params: {
        photo: { image: fixture_file_upload("observation.png", "image/png"), taken_on: "" }
      }
    end
    assert_response :unprocessable_content
  end

  test "le palmarès d'un exercice sans suffrage l'énonce sans détour" do
    get palmares_path(year: 2019)

    assert_response :success
    assert_select ".etat-vide", /Aucun suffrage n'a été exprimé/
  end
end
