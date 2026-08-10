require "test_helper"

class RoundaboutTest < ActiveSupport::TestCase
  setup do
    @roundabout = Roundabout.create!(lat: 44.837789, lon: -0.579180, diameter_m: 42.0,
      commune: "Bordeaux", departement: "Gironde")
  end

  test "réapparie un relevé situé à moins de soixante-dix mètres" do
    assert_equal @roundabout, Roundabout.matching_position(44.838089, -0.579180)
  end

  test "n'apparie pas un relevé situé au-delà de soixante-dix mètres" do
    assert_nil Roundabout.matching_position(44.838789, -0.579180)
  end

  test "n'apparie pas un relevé situé dans l'angle de l'emprise de recherche" do
    assert_nil Roundabout.matching_position(44.838339, -0.578410)
  end

  test "retient le plus proche lorsque deux ouvrages sont candidats" do
    voisin = Roundabout.create!(lat: 44.838239, lon: -0.579180)

    assert_equal voisin, Roundabout.matching_position(44.838200, -0.579180)
  end

  test "le seuil de diamètre ne filtre que l'affichage" do
    petit = Roundabout.create!(lat: 45.0, lon: 0.0, diameter_m: 12.0)

    assert_includes Roundabout.at_least(20), @roundabout
    assert_not_includes Roundabout.at_least(20), petit
  end

  test "un ouvrage sans dénomination reste désignable" do
    assert_equal "Rond-point sans nom", @roundabout.designation
  end

  test "les coordonnées portent leur orientation" do
    assert_equal "44,837789 N, 0,579180 O", @roundabout.coordinates
  end
end
