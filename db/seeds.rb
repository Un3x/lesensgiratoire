ATTRIBUTES = %w[diameter_m name osm_way_ids commune insee_code departement region].freeze

files = Rails.root.glob("db/seeds/*.json").sort
abort "Aucun fichier de recensement dans db/seeds." if files.empty?

files.each do |file|
  created = updated = 0

  JSON.parse(file.read).each do |record|
    lat = record.fetch("lat")
    lon = record.fetch("lon")

    roundabout = Roundabout.matching_position(lat, lon) || Roundabout.new(lat: lat, lon: lon)
    roundabout.new_record? ? created += 1 : updated += 1
    roundabout.assign_attributes(record.slice(*ATTRIBUTES))
    roundabout.save!
  end

  puts "#{file.basename} : #{created} inscriptions, #{updated} mises à jour."
end
