class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  helper_method :voter_token, :avis_du_visiteur

  private
    def voter_token
      session[:voter_token] ||= SecureRandom.uuid
    end

    def avis_du_visiteur(roundabout)
      roundabout.votes.find_by(year: Date.current.year, voter_token: voter_token)
    end
end
