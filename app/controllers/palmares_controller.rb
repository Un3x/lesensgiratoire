class PalmaresController < ApplicationController
  TOP = 20

  def show
    @year = (params[:year] || Date.current.year).to_i
    @years = (Vote.distinct.pluck(:year) | [ Date.current.year ]).sort.reverse
    @rankings = Vote::CATEGORIES.index_with { classement(it) }
  end

  private
    def classement(category)
      Roundabout
        .joins(:votes)
        .where(votes: { category: category, year: @year })
        .select("roundabouts.*, COUNT(votes.id) AS suffrages")
        .group("roundabouts.id")
        .order(Arel.sql("COUNT(votes.id) DESC"), :id)
        .limit(TOP)
    end
end
