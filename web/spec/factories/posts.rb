FactoryBot.define do
  factory :post do
    sequence(:body) { |n| "Post number #{n}" }
    user
  end
end
