# Seeds a handful of posts so the feed has something to render in development.
# Idempotent: re-running does not duplicate the sample posts.

SAMPLE_POSTS = [
  [ "ada", "Just deployed the first version of the feed. It renders." ],
  [ "grace", "Reverse-chronological, no algorithm. As it should be." ],
  [ "linus", "Turbo Streams mean the new post appears without a page reload." ],
  [ "ada", "Cursor pagination, so the timeline does not shuffle under you." ],
  [ "grace", "Still on SQLite. Postgres is one environment variable away." ]
].freeze

SAMPLE_POSTS.each_with_index do |(author_name, body), index|
  next if Post.exists?(body: body)

  # Space the posts out so the timeline ordering is visible at a glance.
  Post.create!(body: body, author_name: author_name, created_at: (SAMPLE_POSTS.size - index).minutes.ago)
end

puts "Seeded #{Post.count} posts."
