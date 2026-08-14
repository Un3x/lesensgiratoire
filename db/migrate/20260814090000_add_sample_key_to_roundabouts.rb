class AddSampleKeyToRoundabouts < ActiveRecord::Migration[8.1]
  def up
    add_column :roundabouts, :sample_key, :integer
    execute "UPDATE roundabouts SET sample_key = (random() * 2147483647)::integer"
    change_column_default :roundabouts, :sample_key, from: nil, to: -> { "(random() * 2147483647)::integer" }
    change_column_null :roundabouts, :sample_key, false

    add_index :roundabouts, :sample_key
  end

  def down
    remove_column :roundabouts, :sample_key
  end
end
