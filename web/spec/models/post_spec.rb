require "rails_helper"

RSpec.describe Post do
  describe "validations" do
    it "is valid with a body and an author name" do
      expect(build(:post)).to be_valid
    end

    it "requires a body" do
      post = build(:post, body: "")

      expect(post).not_to be_valid
      expect(post.errors[:body]).to be_present
    end

    it "rejects a body longer than the maximum" do
      post = build(:post, body: "a" * (Post::MAX_BODY_LENGTH + 1))

      expect(post).not_to be_valid
      expect(post.errors[:body]).to be_present
    end

    it "accepts a body exactly at the maximum" do
      expect(build(:post, body: "a" * Post::MAX_BODY_LENGTH)).to be_valid
    end

    it "rejects an author name longer than the maximum" do
      post = build(:post, author_name: "a" * (Post::MAX_AUTHOR_NAME_LENGTH + 1))

      expect(post).not_to be_valid
      expect(post.errors[:author_name]).to be_present
    end
  end

  describe "default author name" do
    it "falls back to the default when the author name is blank" do
      post = create(:post, author_name: "")

      expect(post.author_name).to eq(Post::DEFAULT_AUTHOR_NAME)
    end

    it "leaves a supplied author name alone" do
      expect(create(:post, author_name: "ada").author_name).to eq("ada")
    end
  end

  describe ".timeline" do
    it "orders newest first" do
      older = create(:post, created_at: 2.hours.ago)
      newer = create(:post, created_at: 1.hour.ago)

      expect(Post.timeline).to eq([ newer, older ])
    end

    it "breaks ties on created_at by id, newest first" do
      timestamp = 1.hour.ago
      first = create(:post, created_at: timestamp)
      second = create(:post, created_at: timestamp)

      expect(Post.timeline).to eq([ second, first ])
    end
  end

  describe ".older_than" do
    it "excludes the post the cursor points at and everything newer" do
      oldest = create(:post, created_at: 3.hours.ago)
      middle = create(:post, created_at: 2.hours.ago)
      create(:post, created_at: 1.hour.ago)

      result = Post.timeline.older_than(middle.created_at, middle.id)

      expect(result).to eq([ oldest ])
    end

    it "uses the id tie-break when timestamps are identical" do
      timestamp = 1.hour.ago
      first = create(:post, created_at: timestamp)
      second = create(:post, created_at: timestamp)

      result = Post.timeline.older_than(second.created_at, second.id)

      expect(result).to eq([ first ])
    end
  end

  describe ".parse_cursor" do
    it "round-trips a cursor produced by #cursor" do
      post = create(:post)

      created_at, id = Post.parse_cursor(post.cursor)

      expect(id).to eq(post.id)
      expect(created_at).to be_within(0.001.seconds).of(post.created_at)
    end

    it "returns nil for blank, malformed and non-numeric cursors" do
      expect(Post.parse_cursor(nil)).to be_nil
      expect(Post.parse_cursor("")).to be_nil
      expect(Post.parse_cursor("nonsense")).to be_nil
      expect(Post.parse_cursor("2026-01-01T00:00:00Z,abc")).to be_nil
    end

    # Time.zone.parse returns nil for an unparseable string rather than raising,
    # so the rescue below it never fires. A [nil, id] pair reaching the query
    # compares every row against NULL and matches nothing, which showed an empty
    # feed instead of the first page.
    it "returns nil when the timestamp is unparseable but the shape is valid" do
      expect(Post.parse_cursor("garbage,42")).to be_nil
      expect(Post.parse_cursor("not-a-time,1")).to be_nil
    end
  end
end
