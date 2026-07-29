# Seeds a few accounts and posts so the feed has something to render in
# development. Idempotent: re-running does not duplicate anything.
#
# Posts belong to users now, so seeding the feed means seeding the accounts that
# wrote it.

SAMPLE_PASSWORD = "seeded-password".freeze

SAMPLE_POSTS = [
  [ "ada", "Just deployed the first version of the feed. It renders." ],
  [ "grace", "Reverse-chronological, no algorithm. As it should be." ],
  [ "linus", "Turbo Streams mean the new post appears without a page reload." ],
  [ "ada", "Cursor pagination, so the timeline does not shuffle under you." ],
  [ "grace", "Still on SQLite. Postgres is one environment variable away." ]
].freeze

authors = SAMPLE_POSTS.map(&:first).uniq.to_h do |name|
  user = User.find_or_create_by!(email_address: "#{name}@example.com") do |u|
    u.password = SAMPLE_PASSWORD
  end
  [ name, user ]
end

SAMPLE_POSTS.each_with_index do |(name, body), index|
  next if Post.exists?(body: body)

  # Space the posts out so the timeline ordering is visible at a glance.
  authors.fetch(name).posts.create!(
    body: body,
    created_at: (SAMPLE_POSTS.size - index).minutes.ago
  )
end

puts "Seeded #{User.count} users and #{Post.count} posts."
puts "Sign in as #{authors.keys.map { |n| "#{n}@example.com" }.join(', ')} — password #{SAMPLE_PASSWORD.inspect}."
