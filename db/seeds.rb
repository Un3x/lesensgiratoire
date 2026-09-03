files = Rails.root.glob("db/seeds/*.json{,.gz}").sort
abort "Aucun fichier de recensement dans db/seeds." if files.empty?

files.each do |file|
  releve = Roundabout.charger_recensement(file)
  puts "#{file.basename} : #{releve[:inscrits]} inscriptions, #{releve[:mis_a_jour]} mises à jour."
end
