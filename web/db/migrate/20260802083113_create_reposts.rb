class CreateReposts < ActiveRecord::Migration[8.1]
  def change
    create_table :reposts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :post, null: false, foreign_key: true

      t.timestamps
    end

    add_index :reposts, [ :user_id, :post_id ], unique: true
    add_column :posts, :reposts_count, :integer, default: 0, null: false
  end
end
