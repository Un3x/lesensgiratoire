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
    assert_not releve["sampled"]
  end

  test "le seuil de diamètre est réglable par le consultant" do
    get roundabouts_path(format: :json, bbox: "-1.0,44.5,0.0,45.0", min_diameter: 5)

    assert_equal 2, response.parsed_body["total"]
  end

  test "la carte se restreint à un régime de priorité et ignore un régime inconnu" do
    etoile = Roundabout.create!(lat: 44.845000, lon: -0.585000, diameter_m: 137.6, junction_type: "circular")

    get roundabouts_path(format: :json, bbox: "-1.0,44.5,0.0,45.0", junction_type: "circular")
    assert_equal [ etoile.id ], response.parsed_body["roundabouts"].map { it["id"] }

    get roundabouts_path(format: :json, bbox: "-1.0,44.5,0.0,45.0", junction_type: "roundabout")
    assert_equal [ @roundabout.id ], response.parsed_body["roundabouts"].map { it["id"] }

    get roundabouts_path(format: :json, bbox: "-1.0,44.5,0.0,45.0", junction_type: "autre")
    assert_equal 2, response.parsed_body["total"]
  end

  test "la fiche énonce le régime de priorité de l'ouvrage" do
    get roundabout_path(@roundabout)
    assert_select "dt", "Régime de priorité"
    assert_select "dd", "À l'anneau (carrefour à sens giratoire)"

    @roundabout.circular!
    get roundabout_path(@roundabout)
    assert_select "dd", "À l'entrant (rond-point)"
  end

  test "une emprise hors de France ne renvoie aucun ouvrage" do
    get roundabouts_path(format: :json, bbox: "10.0,50.0,11.0,51.0")

    assert_equal 0, response.parsed_body["total"]
  end

  test "de la carte à la fiche puis à l'avis jusqu'au palmarès" do
    get root_path
    assert_response :success

    get roundabout_path(@roundabout)
    assert_response :success
    assert_select "h1", /Rond-point sans nom/

    assert_difference -> { Vote.count }, 1 do
      post roundabout_votes_path(@roundabout, liked: false)
    end
    assert_redirected_to @roundabout

    get palmares_path(year: Date.current.year)
    assert_response :success
    assert_select ".classement td", text: "Rond-point sans nom"
  end

  test "un second avis du même visiteur révise le premier" do
    post roundabout_votes_path(@roundabout, liked: false)

    assert_no_difference -> { Vote.count } do
      post roundabout_votes_path(@roundabout, liked: true)
    end
    assert @roundabout.votes.sole.liked?

    get roundabout_path(@roundabout)
    assert_select ".avis__exprime", count: 1
  end

  test "un avis dépourvu de sens est refusé" do
    assert_no_difference -> { Vote.count } do
      post roundabout_votes_path(@roundabout)
    end
    assert_redirected_to @roundabout
  end

  test "les deux classements de l'exercice reposent sur le sens de l'avis" do
    autre = Roundabout.create!(lat: 44.9, lon: -0.6, diameter_m: 30.0, commune: "Mérignac")
    Vote.create!(roundabout: @roundabout, liked: true, year: Date.current.year, voter_token: "jeton")
    Vote.create!(roundabout: autre, liked: false, year: Date.current.year, voter_token: "jeton")

    get palmares_path(year: Date.current.year)

    assert_select ".palmares__categorie", count: 2
    assert_select ".palmares__categorie:first-of-type .classement td", text: "Bordeaux"
    assert_select ".palmares__categorie:first-of-type .classement td", text: "Mérignac", count: 0
    assert_select ".palmares__categorie:last-of-type .classement td", text: "Mérignac"
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

  test "le palmarès d'un exercice sans avis l'énonce sans détour" do
    get palmares_path(year: 2019)

    assert_response :success
    assert_select ".etat-vide", /Aucun avis de cette nature n'a été exprimé/
  end
end
