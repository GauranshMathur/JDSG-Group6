class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.text :body, null: false
      t.string :author_name, null: false

      t.timestamps
    end

    # The timeline is ordered by created_at descending with id as a tie-breaker,
    # so that posts written within the same clock tick have a stable order. That
    # same pair is the keyset pagination cursor, so this index serves both.
    add_index :posts, [ :created_at, :id ], order: { created_at: :desc, id: :desc }
  end
end
