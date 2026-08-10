class VotesController < ApplicationController
  def create
    roundabout = Roundabout.find(params[:roundabout_id])
    avis = roundabout.votes.find_or_initialize_by(year: Date.current.year, voter_token: voter_token)
    avis.liked = { "true" => true, "false" => false }[params[:liked]]
    suite = if avis.new_record? then "enregistré" elsif avis.changed? then "révisé" else "confirmé" end

    if avis.save
      redirect_to roundabout, notice: "Votre avis #{avis.liked? ? "favorable" : "défavorable"} a été #{suite} au titre de l'exercice #{avis.year}."
    else
      redirect_to roundabout, alert: "Votre avis n'a pas été enregistré : il #{avis.errors.messages_for(:liked).first}."
    end
  end
end
