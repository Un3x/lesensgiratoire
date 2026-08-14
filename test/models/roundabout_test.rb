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

  test "l'échantillon d'affichage est stable d'un relevé à l'autre" do
    40.times { |i| Roundabout.create!(lat: 45.0 + i / 1000.0, lon: 1.0, diameter_m: 20 + i) }

    premier = Roundabout.echantillon(10).pluck(:id)

    assert_equal 10, premier.size
    assert_equal premier, Roundabout.echantillon(10).pluck(:id)
  end

  test "l'échantillon ne privilégie pas les grands ouvrages" do
    100.times { |i| Roundabout.create!(lat: 46.0 + i / 1000.0, lon: 2.0, diameter_m: 20 + i) }

    tires = Roundabout.where(lon: 2.0).echantillon(20).pluck(:diameter_m).map(&:to_f)
    plus_grands = Roundabout.where(lon: 2.0).order(diameter_m: :desc).limit(20).pluck(:diameter_m).map(&:to_f)

    assert_operator tires.sum / tires.size, :<, plus_grands.sum / plus_grands.size
  end

  test "chaque ouvrage reçoit une clé d'échantillonnage à l'inscription" do
    assert_predicate Roundabout.create!(lat: 47.0, lon: 3.0).sample_key, :present?
  end

  test "le seuil de diamètre ne filtre que l'affichage" do
    petit = Roundabout.create!(lat: 45.0, lon: 0.0, diameter_m: 12.0)

    assert_includes Roundabout.at_least(20), @roundabout
    assert_not_includes Roundabout.at_least(20), petit
  end

  test "un ouvrage sans dénomination reste désignable" do
    assert_equal "Rond-point sans nom", @roundabout.designation
  end

  test "l'échelle de la vue zénithale suit le diamètre de l'ouvrage" do
    petit = Roundabout.create!(lat: 44.8, lon: -0.5, diameter_m: 18.0)
    grand = Roundabout.create!(lat: 44.8, lon: -0.4, diameter_m: 130.0)

    assert_operator petit.display_zoom, :>, grand.display_zoom
    assert_includes 15..20, petit.display_zoom
    assert_includes 15..20, grand.display_zoom
  end

  test "un ouvrage non mesuré reste cadrable" do
    sans_mesure = Roundabout.create!(lat: 44.8, lon: -0.3)

    assert_includes 15..20, sans_mesure.display_zoom
  end

  test "les coordonnées portent leur orientation" do
    assert_equal "44,837789 N, 0,579180 O", @roundabout.coordinates
  end
end
