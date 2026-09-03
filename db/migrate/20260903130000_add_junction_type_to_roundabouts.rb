class AddJunctionTypeToRoundabouts < ActiveRecord::Migration[8.1]
  def change
    add_column :roundabouts, :junction_type, :string, null: false, default: "roundabout"
    add_index :roundabouts, :junction_type
  end
end
