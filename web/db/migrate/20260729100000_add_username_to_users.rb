class AddUsernameToUsers < ActiveRecord::Migration[8.1]
  # Usernames are chosen at registration and never change — ADR 0006. Existing
  # accounts predate the column, so they get one derived from the local part of
  # their email address, deduplicated with a numeric suffix.
  #
  # Same licence as milestone 3's backfill: acceptable precisely because these
  # are seeded development accounts. Inventing permanent public identities for
  # real users would not be.
  def up
    add_column :users, :username, :string

    backfill_usernames

    change_column_null :users, :username, false
    add_index :users, :username, unique: true
  end

  def down
    remove_index :users, :username
    remove_column :users, :username
  end

  private

    # A bare Active Record class rather than the User model, so the migration
    # keeps working when the model above it changes. In particular the model
    # will declare this column attr_readonly, which would refuse the very
    # backfill this migration exists to do.
    def backfill_usernames
      users = Class.new(ActiveRecord::Base) { self.table_name = "users" }

      users.where(username: nil).order(:id).each do |user|
        user.update!(username: available_username_for(user.email_address, users))
      end
    end

    def available_username_for(email_address, users)
      base = email_address.to_s.split("@").first.to_s.downcase
                          .gsub(/[^a-z0-9_]/, "_")[0, 20].ljust(3, "_")

      candidate = base
      suffix = 1
      while users.exists?(username: candidate)
        suffix += 1
        candidate = "#{base[0, 20 - suffix.to_s.length]}#{suffix}"
      end
      candidate
    end
end
