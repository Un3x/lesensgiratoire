ENV["RAILS_ENV"] ||= "test"
ENV["VALIDATION_MOT_DE_PASSE"] ||= "secret"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include ActionDispatch::TestProcess::FixtureFile

    def avec_lecture_distante(lecture)
      Photo.singleton_class.alias_method :lire_json_reelle, :lire_json
      Photo.define_singleton_method(:lire_json, &lecture)
      yield
    ensure
      Photo.singleton_class.alias_method :lire_json, :lire_json_reelle
    end
  end
end
