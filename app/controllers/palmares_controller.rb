class PalmaresController < ApplicationController
  TOP = 20

  def show
    @year = (params[:year] || Date.current.year).to_i
    @years = (Vote.distinct.pluck(:year) | [ Date.current.year ]).sort.reverse
    @classements = [
      { titre: "Les ronds-points les plus appréciés", colonne: "Avis favorables", ouvrages: classement(true) },
      { titre: "Les ronds-points les moins appréciés", colonne: "Avis défavorables", ouvrages: classement(false) }
    ]
  end

  private
    def classement(liked)
      Roundabout
        .joins(:votes)
        .where(votes: { liked: liked, year: @year })
        .select("roundabouts.*, COUNT(votes.id) AS avis")
        .group("roundabouts.id")
        .order(Arel.sql("COUNT(votes.id) DESC"), :id)
        .limit(TOP)
    end
end
