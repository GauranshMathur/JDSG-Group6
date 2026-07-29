class User < ApplicationRecord
  MINIMUM_PASSWORD_LENGTH = 8

  has_secure_password
  has_many :sessions, dependent: :destroy

  # Not dependent: :destroy. Posts outlive the account that wrote them — see
  # ADR 0005 — so destroying a user with posts is refused rather than quietly
  # taking the posts with it. The foreign key refuses it at the database level
  # too; this makes the refusal an error you can read.
  has_many :posts, dependent: :restrict_with_error

  # Addresses are stored already lower-cased, so the unique index on the column
  # enforces case-insensitive uniqueness on its own (F-2.2). The alternative — a
  # functional index over LOWER(email_address) — is written differently on SQLite
  # and PostgreSQL, which N-1.2 rules out.
  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP },
                            uniqueness: true

  # allow_nil so a user can be updated without resupplying a password.
  # has_secure_password already requires one to be present on create.
  validates :password, length: { minimum: MINIMUM_PASSWORD_LENGTH }, allow_nil: true

  # What the feed shows next to a post. The local part only: the timeline is
  # public, and publishing full email addresses to anyone who loads the page
  # invites scraping.
  #
  # Temporary. Milestone 4 adds a real username and this goes away — until then
  # two people at different domains with the same local part are indistinguishable
  # on screen, though they remain distinct accounts.
  def display_name
    email_address.split("@").first
  end
end
