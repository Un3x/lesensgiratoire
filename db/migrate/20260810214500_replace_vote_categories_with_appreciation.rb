class ReplaceVoteCategoriesWithAppreciation < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM votes"

    remove_index :votes, name: "index_votes_uniqueness"
    remove_index :votes, [ :category, :year ]
    remove_column :votes, :category
    add_column :votes, :liked, :boolean, null: false

    add_index :votes, [ :roundabout_id, :year, :voter_token ], unique: true, name: "index_votes_uniqueness"
    add_index :votes, [ :year, :liked ]
  end

  def down
    execute "DELETE FROM votes"

    remove_index :votes, name: "index_votes_uniqueness"
    remove_index :votes, [ :year, :liked ]
    remove_column :votes, :liked
    add_column :votes, :category, :string, null: false

    add_index :votes, [ :roundabout_id, :category, :year, :voter_token ], unique: true, name: "index_votes_uniqueness"
    add_index :votes, [ :category, :year ]
  end
end
