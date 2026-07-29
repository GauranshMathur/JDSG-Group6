class User < ApplicationRecord
  MINIMUM_PASSWORD_LENGTH = 8

  has_secure_password
  has_many :sessions, dependent: :destroy

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
end
