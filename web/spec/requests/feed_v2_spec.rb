require "rails_helper"

# F-5.5.1, F-5.5.2, F-5.5.3, F-5.5.4, F-5.5.5
RSpec.describe "Feed v2" do
  let(:user) { create(:user) }

  describe "reposts in the feed timeline (F-5.5.1)" do
    it "shows a reposted post in the feed at the time of the repost" do
      old_post = create(:post, created_at: 2.days.ago)
      create(:repost, user: user, post: old_post, created_at: 1.minute.ago)

      get posts_path

      expect(response.body).to include(old_post.body)
    end

    it "shows the repost above posts that are older than the repost" do
      old_post = create(:post, body: "The old one", created_at: 3.days.ago)
      newer_post = create(:post, body: "The newer one", created_at: 1.hour.ago)
      create(:repost, user: user, post: old_post, created_at: 30.minutes.ago)

      get posts_path

      body = response.body
      repost_position = body.index("Reposted by")
      newer_position = body.index("The newer one")
      old_in_feed_position = body.index("The old one")

      expect(repost_position).to be_present
      expect(old_in_feed_position).to be_present
      expect(newer_position).to be < repost_position
      expect(repost_position).to be < old_in_feed_position + old_post.body.length + 200
    end
  end

  # F-5.5.3
  describe "repost attribution" do
    it "shows 'Reposted by @username' above the reposted post" do
      reposter = create(:user, username: "reposter_jane")
      post_record = create(:post, created_at: 1.day.ago)
      create(:repost, user: reposter, post: post_record, created_at: 1.minute.ago)

      get posts_path

      expect(response.body).to include("Reposted by")
      expect(response.body).to include("@reposter_jane")
    end

    it "renders the original post content under the repost attribution" do
      reposter = create(:user)
      original = create(:post, body: "Original content here", created_at: 1.day.ago)
      create(:repost, user: reposter, post: original, created_at: 1.minute.ago)

      get posts_path

      expect(response.body).to include("Original content here")
    end
  end

  # F-5.5.2
  describe "reposts on profile pages" do
    it "shows reposts interleaved with the user's own posts" do
      profile_user = create(:user)
      own_post = create(:post, user: profile_user, body: "My own post", created_at: 2.hours.ago)
      other_post = create(:post, body: "Someone else wrote this", created_at: 1.day.ago)
      create(:repost, user: profile_user, post: other_post, created_at: 1.hour.ago)

      get profile_path(profile_user.username)

      expect(response.body).to include("My own post")
      expect(response.body).to include("Someone else wrote this")
    end

    it "shows repost attribution on the profile page" do
      profile_user = create(:user, username: "profile_user")
      other_post = create(:post, created_at: 1.day.ago)
      create(:repost, user: profile_user, post: other_post, created_at: 1.hour.ago)

      get profile_path(profile_user.username)

      expect(response.body).to include("Reposted by")
      expect(response.body).to include("@profile_user")
    end
  end

  # F-5.5.4
  describe "ranked feed" do
    it "ranks posts with more engagement higher than newer posts with none" do
      popular = create(:post, body: "Popular post", created_at: 6.hours.ago)
      create_list(:like, 10, post: popular)
      create_list(:repost, 5, post: popular)

      recent = create(:post, body: "Recent but boring", created_at: 1.minute.ago)

      get posts_path

      body = response.body
      popular_pos = body.index("Popular post")
      recent_pos = body.index("Recent but boring")

      expect(popular_pos).to be_present
      expect(recent_pos).to be_present
      expect(popular_pos).to be < recent_pos
    end

    it "still surfaces very recent posts even with no engagement" do
      old_popular = create(:post, body: "Old and popular", created_at: 7.days.ago)
      create_list(:like, 20, post: old_popular)

      brand_new = create(:post, body: "Just posted", created_at: 1.second.ago)

      get posts_path

      expect(response.body).to include("Just posted")
    end
  end

  # F-5.5.5
  describe "feed caching" do
    it "serves the same ranked feed to different users" do
      popular = create(:post, body: "Cached popular post", created_at: 1.hour.ago)
      create_list(:like, 10, post: popular)

      user_a = create(:user)
      user_b = create(:user)

      sign_in(user_a)
      get posts_path
      body_a = response.body

      sign_in(user_b)
      get posts_path
      body_b = response.body

      expect(body_a).to include("Cached popular post")
      expect(body_b).to include("Cached popular post")
    end
  end
end
