class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  helper_method :voter_token

  private
    def voter_token
      session[:voter_token] ||= SecureRandom.uuid
    end
end
