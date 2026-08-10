require "test_helper"

class VoteTest < ActiveSupport::TestCase
  setup do
    @roundabout = Roundabout.create!(lat: 44.837789, lon: -0.579180, diameter_m: 42.0)
    @vote = Vote.create!(roundabout: @roundabout, category: "plus_beau", year: 2026, voter_token: "jeton")
  end

  test "un même votant ne se prononce qu'une fois par catégorie et par exercice" do
    doublon = Vote.new(roundabout: @roundabout, category: "plus_beau", year: 2026, voter_token: "jeton")

    assert_not doublon.valid?
  end

  test "un même votant se prononce à nouveau l'exercice suivant" do
    assert Vote.new(roundabout: @roundabout, category: "plus_beau", year: 2027, voter_token: "jeton").valid?
  end

  test "un même votant se prononce dans une autre catégorie" do
    assert Vote.new(roundabout: @roundabout, category: "plus_moche", year: 2026, voter_token: "jeton").valid?
  end

  test "une catégorie inconnue est irrecevable" do
    assert_not Vote.new(roundabout: @roundabout, category: nil, year: 2026, voter_token: "jeton").valid?
  end

  test "les suffrages se décomptent par catégorie et par exercice" do
    Vote.create!(roundabout: @roundabout, category: "plus_beau", year: 2026, voter_token: "autre-jeton")
    Vote.create!(roundabout: @roundabout, category: "plus_beau", year: 2025, voter_token: "jeton")

    assert_equal 2, @roundabout.votes_count_for("plus_beau", 2026)
  end
end
