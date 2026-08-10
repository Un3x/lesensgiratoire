class CreateRoundabouts < ActiveRecord::Migration[8.1]
  def change
    create_table :roundabouts do |t|
      t.decimal :lat, precision: 9, scale: 6, null: false
      t.decimal :lon, precision: 9, scale: 6, null: false
      t.decimal :diameter_m, precision: 6, scale: 1
      t.string :name
      t.string :commune
      t.string :insee_code
      t.string :departement
      t.string :region
      t.bigint :osm_way_ids, array: true, default: [], null: false

      t.timestamps
    end

    add_index :roundabouts, [ :lat, :lon ]
    add_index :roundabouts, :diameter_m
    add_index :roundabouts, :insee_code
  end
end
