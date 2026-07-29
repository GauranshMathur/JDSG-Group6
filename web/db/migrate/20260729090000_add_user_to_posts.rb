class AddUserToPosts < ActiveRecord::Migration[8.1]
  # Existing rows predate accounts, so they are attributed to a single
  # placeholder account rather than making the column nullable. A nullable
  # user_id would have to be defended in every query and every view from now on,
  # to describe rows that only exist because of the order we built things in.
  #
  # Safe here precisely because nothing is deployed: these are seeded
  # development posts. Inventing ownership for real user data would not be.
  PLACEHOLDER_EMAIL = "legacy@example.invalid".freeze

  def up
    add_reference :posts, :user, foreign_key: true, index: true

    orphans = select_value("SELECT COUNT(*) FROM posts WHERE user_id IS NULL").to_i
    if orphans.positive?
      say "Attributing #{orphans} pre-accounts post(s) to #{PLACEHOLDER_EMAIL}"
      execute <<~SQL.squish
        UPDATE posts SET user_id = #{placeholder_user_id} WHERE user_id IS NULL
      SQL
    end

    change_column_null :posts, :user_id, false
  end

  def down
    remove_reference :posts, :user, foreign_key: true
  end

  private

    # A bare Active Record class rather than the User model: a migration has to
    # keep working when the model above it changes, and this one only needs two
    # columns. The password is random and discarded — the placeholder exists to
    # own rows, not to be signed into.
    def placeholder_user_id
      users = Class.new(ActiveRecord::Base) { self.table_name = "users" }

      user = users.find_by(email_address: PLACEHOLDER_EMAIL)
      user ||= users.create!(
        email_address: PLACEHOLDER_EMAIL,
        password_digest: BCrypt::Password.create(SecureRandom.hex(32))
      )
      user.id
    end
end
