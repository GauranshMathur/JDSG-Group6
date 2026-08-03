require "rails_helper"

# F-6.5.1, F-6.5.2, F-6.5.3
RSpec.describe RankedFeed do
  around do |example|
    original_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = original_store
  end

  # F-6.5.1
  describe "caching" do
    it "reads from cache on the second call instead of hitting the database" do
      create(:post, body: "cached post")

      RankedFeed.new.items

      query_count = 0
      callback = ->(_name, _start, _finish, _id, payload) {
        query_count += 1 unless payload[:name] == "SCHEMA" || payload[:name] == "CACHE"
      }

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        RankedFeed.new.items
      end

      expect(query_count).to eq(0)
    end

    it "paginates from the cached feed without extra queries" do
      create_list(:post, RankedFeed::PAGE_SIZE + 5)

      RankedFeed.new.items

      query_count = 0
      callback = ->(_name, _start, _finish, _id, payload) {
        query_count += 1 unless payload[:name] == "SCHEMA" || payload[:name] == "CACHE"
      }

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        page2 = RankedFeed.new(page: 1).items
        expect(page2.size).to eq(5)
      end

      expect(query_count).to eq(0)
    end
  end

  # F-6.5.2
  describe "cache invalidation" do
    it "invalidates when a new post is created" do
      post = create(:post, body: "original")
      items = RankedFeed.new.items
      expect(items.map { |i| i.post.body }).to include("original")

      create(:post, body: "brand new")
      items = RankedFeed.new.items
      expect(items.map { |i| i.post.body }).to include("brand new")
    end

    it "invalidates when a post is destroyed" do
      post = create(:post, body: "doomed")
      RankedFeed.new.items

      post.destroy!
      items = RankedFeed.new.items
      expect(items.map { |i| i.post.body }).not_to include("doomed")
    end

    it "invalidates when a like is created" do
      post = create(:post, body: "likeable")
      RankedFeed.new.items

      create(:like, post: post)
      items = RankedFeed.new.items
      liked = items.find { |i| i.post.body == "likeable" }
      expect(liked.post.likes_count).to eq(1)
    end

    it "invalidates when a like is destroyed" do
      post = create(:post, body: "unliked")
      like = create(:like, post: post)
      RankedFeed.new.items

      like.destroy!
      items = RankedFeed.new.items
      found = items.find { |i| i.post.body == "unliked" }
      expect(found.post.likes_count).to eq(0)
    end

    it "invalidates when a repost is created" do
      post = create(:post, body: "repostable")
      RankedFeed.new.items

      repost = create(:repost, post: post)
      items = RankedFeed.new.items
      expect(items.any? { |i| i.repost? && i.post.body == "repostable" }).to be true
    end

    it "invalidates when a repost is destroyed" do
      post = create(:post, body: "unreposted")
      repost = create(:repost, post: post)
      RankedFeed.new.items

      repost.destroy!
      items = RankedFeed.new.items
      expect(items.none? { |i| i.repost? && i.post.body == "unreposted" }).to be true
    end
  end

  # F-6.5.3
  describe "warm on boot" do
    it "populates the cache via RankedFeed.warm" do
      create(:post, body: "warmed post")

      Rails.cache.clear
      RankedFeed.warm

      query_count = 0
      callback = ->(_name, _start, _finish, _id, payload) {
        query_count += 1 unless payload[:name] == "SCHEMA" || payload[:name] == "CACHE"
      }

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        items = RankedFeed.new.items
        expect(items.map { |i| i.post.body }).to include("warmed post")
      end

      expect(query_count).to eq(0)
    end
  end
end
