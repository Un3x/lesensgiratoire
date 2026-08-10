class CreatePhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :photos do |t|
      t.references :roundabout, null: false, foreign_key: true
      t.date :taken_on, null: false
      t.string :author
      t.string :licence
      t.string :source_url

      t.timestamps
    end

    add_index :photos, [ :roundabout_id, :taken_on ]
  end
end
