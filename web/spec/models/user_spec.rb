require "rails_helper"

RSpec.describe User do
  describe "validations" do
    it "is valid with an email address and a long enough password" do
      expect(build(:user)).to be_valid
    end

    it "requires an email address" do
      user = build(:user, email_address: nil)

      expect(user).not_to be_valid
      expect(user.errors[:email_address]).to be_present
    end

    it "rejects an address that is not shaped like an email address" do
      expect(build(:user, email_address: "not-an-email")).not_to be_valid
    end

    it "requires a password on create" do
      user = build(:user, password: nil)

      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it "rejects a password shorter than the minimum" do
      short = "a" * (User::MINIMUM_PASSWORD_LENGTH - 1)

      expect(build(:user, password: short)).not_to be_valid
    end

    it "rejects a mismatched password confirmation" do
      user = build(:user, password: "sekrit-password", password_confirmation: "something-else")

      expect(user).not_to be_valid
    end
  end

  describe "username" do
    it "requires one" do
      user = build(:user, username: nil)

      expect(user).not_to be_valid
      expect(user.errors[:username]).to be_present
    end

    it "rejects characters outside letters, numbers and underscores" do
      expect(build(:user, username: "with-dash")).not_to be_valid
      expect(build(:user, username: "with space")).not_to be_valid
      expect(build(:user, username: "with.dot")).not_to be_valid
    end

    it "rejects one shorter than 3 or longer than 20 characters" do
      expect(build(:user, username: "ab")).not_to be_valid
      expect(build(:user, username: "a" * 21)).not_to be_valid
    end

    # F-4.2, same mechanism as email (F-2.2): stored lower-cased, so the plain
    # unique index is case-insensitive without anything adapter-specific.
    it "stores usernames lower-cased and stripped" do
      expect(create(:user, username: "  Ada_99  ").username).to eq("ada_99")
    end

    it "rejects a duplicate differing only in case" do
      create(:user, username: "ada")

      expect(build(:user, username: "ADA")).not_to be_valid
    end

    # F-4.6 / ADR 0007. Usernames are changeable but must stay unique.
    it "can be changed on a persisted record" do
      user = create(:user, username: "ada")

      user.update!(username: "ada_lovelace")

      expect(user.reload.username).to eq("ada_lovelace")
    end

    it "rejects a username change to one already taken" do
      create(:user, username: "ada")
      user = create(:user, username: "grace")

      user.username = "ada"

      expect(user).not_to be_valid
      expect(user.errors[:username]).to include("has already been taken")
    end
  end

  describe "#name" do
    it "is the display name when one is set" do
      expect(build(:user, username: "ada", display_name: "Ada Lovelace").name).to eq("Ada Lovelace")
    end

    it "falls back to the username when there is none" do
      expect(build(:user, username: "ada", display_name: nil).name).to eq("ada")
      expect(build(:user, username: "ada", display_name: "").name).to eq("ada")
    end
  end

  describe "profile fields" do
    it "accepts a display name and bio at their limits" do
      user = build(:user, display_name: "a" * User::MAX_DISPLAY_NAME_LENGTH,
                          bio: "b" * User::MAX_BIO_LENGTH)

      expect(user).to be_valid
    end

    it "rejects a display name over the limit" do
      expect(build(:user, display_name: "a" * (User::MAX_DISPLAY_NAME_LENGTH + 1))).not_to be_valid
    end

    it "rejects a bio over the limit" do
      expect(build(:user, bio: "b" * (User::MAX_BIO_LENGTH + 1))).not_to be_valid
    end
  end

  describe "email address uniqueness" do
    it "rejects a duplicate address" do
      create(:user, email_address: "ada@example.com")

      expect(build(:user, email_address: "ada@example.com")).not_to be_valid
    end

    # F-2.2. Uniqueness is case-insensitive because addresses are normalised to
    # lower case before they are written, not because of a case-insensitive index.
    it "rejects a duplicate address differing only in case" do
      create(:user, email_address: "ada@example.com")

      expect(build(:user, email_address: "ADA@Example.com")).not_to be_valid
    end

    it "stores addresses lower-cased and stripped" do
      user = create(:user, email_address: "  Ada@Example.COM  ")

      expect(user.email_address).to eq("ada@example.com")
    end
  end

  describe "authentication" do
    it "authenticates with the right password" do
      user = create(:user, email_address: "ada@example.com")

      found = User.authenticate_by(email_address: "ada@example.com",
                                   password: AuthenticationHelpers::DEFAULT_PASSWORD)

      expect(found).to eq(user)
    end

    it "authenticates regardless of the case the address is typed in" do
      user = create(:user, email_address: "ada@example.com")

      found = User.authenticate_by(email_address: "ADA@EXAMPLE.COM",
                                   password: AuthenticationHelpers::DEFAULT_PASSWORD)

      expect(found).to eq(user)
    end

    it "does not authenticate with the wrong password" do
      create(:user, email_address: "ada@example.com")

      found = User.authenticate_by(email_address: "ada@example.com", password: "wrong-password")

      expect(found).to be_nil
    end

    it "does not store the password in the clear" do
      user = create(:user)

      expect(user.password_digest).to be_present
      expect(user.password_digest).not_to include(AuthenticationHelpers::DEFAULT_PASSWORD)
    end
  end

  describe "sessions" do
    it "destroys its sessions when the user is destroyed" do
      user = create(:user)
      user.sessions.create!

      expect { user.destroy }.to change(Session, :count).by(-1)
    end
  end
end
