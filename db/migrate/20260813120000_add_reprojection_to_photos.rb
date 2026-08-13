class AddReprojectionToPhotos < ActiveRecord::Migration[8.1]
  def change
    add_column :photos, :heading, :float
    add_column :photos, :pitch, :float
    add_column :photos, :field_of_view, :float
  end
end
