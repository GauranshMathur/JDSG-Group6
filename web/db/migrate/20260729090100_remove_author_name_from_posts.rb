class RemoveAuthorNameFromPosts < ActiveRecord::Migration[8.1]
  # Authorship now comes from the association. Kept as a separate migration from
  # the backfill so that the attribution can be inspected before the free-text
  # name it replaced is dropped.
  def change
    remove_column :posts, :author_name, :string, null: false
  end
end
