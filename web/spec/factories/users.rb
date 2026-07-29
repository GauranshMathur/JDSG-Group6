FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "user#{n}@example.com" }
    sequence(:username) { |n| "user#{n}" }
    password { AuthenticationHelpers::DEFAULT_PASSWORD }
  end
end
