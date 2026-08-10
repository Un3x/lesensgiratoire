class VotesController < ApplicationController
  def create
    roundabout = Roundabout.find(params[:roundabout_id])
    vote = roundabout.votes.new(
      category: params[:category].presence_in(Vote::CATEGORIES),
      year: Date.current.year,
      voter_token: voter_token
    )

    if vote.save
      redirect_to roundabout, notice: "Votre suffrage a été enregistré au titre de l'exercice #{vote.year}."
    else
      redirect_to roundabout, alert: "Le suffrage n'a pas été enregistré : ce rond-point #{vote.errors.messages_for(:roundabout_id).first || "ne peut être retenu dans cette catégorie"}."
    end
  end
end
