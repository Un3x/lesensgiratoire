require "test_helper"

class VoteTest < ActiveSupport::TestCase
  setup do
    @roundabout = Roundabout.create!(lat: 44.837789, lon: -0.579180, diameter_m: 42.0)
    @avis = Vote.create!(roundabout: @roundabout, liked: true, year: 2026, voter_token: "jeton")
  end

  test "un même visiteur n'exprime qu'un avis par ouvrage et par exercice" do
    doublon = Vote.new(roundabout: @roundabout, liked: false, year: 2026, voter_token: "jeton")

    assert_not doublon.valid?
  end

  test "un même visiteur se prononce à nouveau l'exercice suivant" do
    assert Vote.new(roundabout: @roundabout, liked: true, year: 2027, voter_token: "jeton").valid?
  end

  test "un même visiteur se prononce sur un autre ouvrage" do
    autre = Roundabout.create!(lat: 45.0, lon: 0.0, diameter_m: 30.0)

    assert Vote.new(roundabout: autre, liked: false, year: 2026, voter_token: "jeton").valid?
  end

  test "un avis sans sens est irrecevable" do
    avis = Vote.new(roundabout: @roundabout, liked: nil, year: 2026, voter_token: "autre-jeton")

    assert_not avis.valid?
    assert_includes avis.errors.attribute_names, :liked
  end

  test "un avis est révisable sans créer de second avis" do
    @avis.update!(liked: false)

    assert_equal 1, @roundabout.votes.for_year(2026).count
    assert_not @roundabout.votes.for_year(2026).sole.liked?
  end

  test "les avis se décomptent par sens et par exercice" do
    Vote.create!(roundabout: @roundabout, liked: true, year: 2026, voter_token: "deuxieme-jeton")
    Vote.create!(roundabout: @roundabout, liked: false, year: 2026, voter_token: "troisieme-jeton")
    Vote.create!(roundabout: @roundabout, liked: true, year: 2025, voter_token: "jeton")

    assert_equal({ true => 2, false => 1 }, @roundabout.appreciations(2026))
  end
end
