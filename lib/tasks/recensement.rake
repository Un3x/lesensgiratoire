namespace :recensement do
  desc "Enrichit un recensement des ways junction=circular relevés sur Overpass"
  task :circulaires, [ :source, :destination ] => :environment do |_tache, args|
    abort "Usage : bin/rails recensement:circulaires[source.json.gz,destination.json.gz]" if args[:source].blank? || args[:destination].blank?
    abort "Fichier introuvable : #{args[:source]}" unless File.exist?(args[:source])

    lire = ->(chemin) { chemin.end_with?(".gz") ? Zlib::GzipReader.open(chemin) { it.read } : File.read(chemin) }
    records = JSON.parse(lire.(args[:source]))
    ways = Roundabout.ways_circulaires
    puts "#{records.size} ouvrages recensés, #{ways.size} ways circulaires relevés."

    geocodages = 0
    releve = Roundabout.enrichir_recensement(records, ways) do |lat, lon|
      geocodages += 1
      Roundabout.adresse_ban(lat, lon)
    end

    contenu = JSON.pretty_generate(releve)
    if args[:destination].end_with?(".gz")
      Zlib::GzipWriter.open(args[:destination]) { it.write(contenu) }
    else
      File.write(args[:destination], contenu)
    end

    circulaires = releve.count { it["junction_type"] == "circular" }
    puts "#{releve.size} ouvrages écrits dans #{args[:destination]}, dont #{circulaires} à priorité à l'entrant."
    puts "#{releve.size - records.size} ouvrages nouveaux, #{geocodages} géocodés."
  end
end
