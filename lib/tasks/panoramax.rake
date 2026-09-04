namespace :panoramax do
  desc "Moissonne les prises de vue Panoramax autour des ronds-points illustrables"
  task :moisson, [ :depuis, :combien, :regime ] => :environment do |_tache, args|
    depuis = args[:depuis].to_i
    combien = (args[:combien] || 500).to_i

    ouvrages = args[:regime].present? ? Roundabout.public_send(args[:regime]) : Roundabout.where(id: Photo.where.not(image_url: nil).select(:roundabout_id))
    ouvrages = ouvrages.order(:id).offset(depuis).limit(combien)

    puts "Moisson sur #{ouvrages.count} ouvrages, à partir du rang #{depuis}."
    releve = Photo.moissonner_panoramax(ouvrages)

    puts "#{releve[:versees]} observations versées, #{releve[:deja_versees]} déjà présentes."
    puts "#{releve[:retirees]} observations évincées du dossier." if releve[:retirees].positive?
    puts "#{releve[:hors_cadrage]} clichés écartés pour cadrage." if releve[:hors_cadrage].positive?
    puts "#{releve[:injoignables]} ouvrages sans réponse de Panoramax." if releve[:injoignables].positive?
    puts "#{releve[:refusees].size} refusées." if releve[:refusees].any?
  end

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
