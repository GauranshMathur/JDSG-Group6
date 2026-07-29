class AddProfileFieldsToUsers < ActiveRecord::Migration[8.1]
  # Both nullable on purpose: absent means "never provided", and the UI falls
  # back to the username. A NOT NULL default of "" would only turn one blank
  # state into two.
  def change
    add_column :users, :display_name, :string
    add_column :users, :bio, :string
  end
end
