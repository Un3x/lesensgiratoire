class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  helper_method :voter_token, :already_voted?

  private
    def voter_token
      session[:voter_token] ||= SecureRandom.uuid
    end

    def already_voted?(roundabout, category)
      roundabout.votes.exists?(category: category, year: Date.current.year, voter_token: voter_token)
    end
end
