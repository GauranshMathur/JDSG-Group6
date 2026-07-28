FactoryBot.define do
  factory :post do
    sequence(:body) { |n| "Post number #{n}" }
    author_name { "test-user" }
  end
end
