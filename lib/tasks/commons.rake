namespace :commons do
  desc "Référence l'image Wikimedia Commons (Wikidata P18) des ouvrages à priorité à l'entrant"
  task illustrer: :environment do
    ouvrages = Roundabout.circular.order(:id)
    puts "Illustration depuis Commons sur #{ouvrages.count} ouvrages."
    releve = Photo.illustrer_depuis_commons(ouvrages)

    puts "#{releve[:versees]} observations versées, #{releve[:deja_versees]} déjà présentes."
    puts "#{releve[:injoignables]} ouvrages sans réponse." if releve[:injoignables].positive?
    releve[:refusees].each { puts "  refusée : #{it}" }
  end
end
