class AddValidatedAtToPhotos < ActiveRecord::Migration[8.1]
  def change
    add_column :photos, :validated_at, :datetime
    add_index :photos, :validated_at, where: "validated_at IS NULL"
    up_only { execute "UPDATE photos SET validated_at = updated_at" }
  end
end
