class AddImageUrlToPhotos < ActiveRecord::Migration[8.1]
  def change
    add_column :photos, :image_url, :string

    add_index :photos, [ :roundabout_id, :image_url ], unique: true, where: "image_url IS NOT NULL"
  end
end
