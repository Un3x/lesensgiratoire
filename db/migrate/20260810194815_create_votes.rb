class CreateVotes < ActiveRecord::Migration[8.1]
  def change
    create_table :votes do |t|
      t.references :roundabout, null: false, foreign_key: true
      t.string :category, null: false
      t.integer :year, null: false
      t.string :voter_token, null: false

      t.timestamps
    end

    add_index :votes, [ :roundabout_id, :category, :year, :voter_token ],
      unique: true, name: "index_votes_uniqueness"
    add_index :votes, [ :category, :year ]
  end
end
