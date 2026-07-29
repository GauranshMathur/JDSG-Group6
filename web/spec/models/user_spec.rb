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
