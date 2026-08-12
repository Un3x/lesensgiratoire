namespace :panoramax do
  desc "Verse au dossier les observations Panoramax d'un fichier JSONL"
  task :import, [ :fichier ] => :environment do |_tache, args|
    abort "Usage : bin/rails panoramax:import[chemin/du/fichier.jsonl]" if args[:fichier].blank?
    abort "Fichier introuvable : #{args[:fichier]}" unless File.exist?(args[:fichier])

    releve = Photo.ingest_panoramax(args[:fichier])

    puts "#{releve[:versees]} observations versées, #{releve[:deja_versees]} déjà présentes."
    puts "#{releve[:hors_cadrage]} écartées, l'axe de visée ne tombant pas sur l'ouvrage, dont #{releve[:retirees]} retirées du dossier." if releve[:hors_cadrage].positive?
    puts "#{releve[:sans_ouvrage]} lignes sans rond-point recensé à cette position." if releve[:sans_ouvrage].positive?

    if releve[:refusees].any?
      puts "#{releve[:refusees].size} lignes refusées :"
      releve[:refusees].first(10).each { puts "  #{it}" }
    end
  end
end
