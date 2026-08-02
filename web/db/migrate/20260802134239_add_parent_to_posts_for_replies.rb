class AddParentToPostsForReplies < ActiveRecord::Migration[8.1]
  def change
    add_reference :posts, :parent, null: true, foreign_key: { to_table: :posts }
    add_column :posts, :replies_count, :integer, default: 0, null: false
  end
end
