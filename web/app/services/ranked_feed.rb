class RankedFeed
  PAGE_SIZE = 20

  def initialize(page: 0)
    @page = page
  end

  def items
    @items ||= build_feed
  end

  def next_page
    @page + 1 if items.size == PAGE_SIZE
  end

  private

  def build_feed
    posts = Post.top_level.eager_load(:user).to_a
    reposts = Repost.eager_load(:user, post: :user).where(post: Post.top_level).to_a

    feed = []

    posts.each do |post|
      feed << FeedItem.new(
        post: post,
        reposter: nil,
        sort_time: post.created_at,
        score: engagement_score(post)
      )
    end

    reposts.each do |repost|
      feed << FeedItem.new(
        post: repost.post,
        reposter: repost.user,
        sort_time: repost.created_at,
        score: engagement_score(repost.post, boost_time: repost.created_at)
      )
    end

    feed
      .sort_by { |item| -item.score }
      .drop(@page * PAGE_SIZE)
      .first(PAGE_SIZE)
  end

  def engagement_score(post, boost_time: nil)
    age_hours = ((Time.current - (boost_time || post.created_at)) / 1.hour).clamp(0, Float::INFINITY)
    engagement = post.likes_count + (post.reposts_count * 2) + post.replies_count
    (engagement + 1).to_f / ((age_hours + 2)**1.5)
  end
end
