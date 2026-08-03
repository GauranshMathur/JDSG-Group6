FeedItem = Data.define(:post, :reposter, :sort_time, :score) do
  def repost?
    reposter.present?
  end
end
