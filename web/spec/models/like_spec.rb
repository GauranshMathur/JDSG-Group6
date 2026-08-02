require "rails_helper"

# F-5.6, F-5.7
RSpec.describe Like do
  describe "validations" do
    it "requires a user and a post" do
      like = Like.new
      expect(like).not_to be_valid
      expect(like.errors[:user]).to be_present
      expect(like.errors[:post]).to be_present
    end

    it "prevents the same user from liking the same post twice" do
      existing = create(:like)
      duplicate = build(:like, user: existing.user, post: existing.post)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
    end

    it "allows different users to like the same post" do
      post_record = create(:post)
      create(:like, post: post_record)
      second = build(:like, post: post_record)
      expect(second).to be_valid
    end
  end

  describe "counter cache" do
    it "increments the post's likes_count on create" do
      post_record = create(:post)
      expect { create(:like, post: post_record) }
        .to change { post_record.reload.likes_count }.from(0).to(1)
    end

    it "decrements the post's likes_count on destroy" do
      like = create(:like)
      post_record = like.post
      expect { like.destroy }
        .to change { post_record.reload.likes_count }.from(1).to(0)
    end
  end

  describe "dependent destroy" do
    it "is destroyed when its post is destroyed" do
      like = create(:like)
      expect { like.post.destroy }.to change(Like, :count).by(-1)
    end

    it "is destroyed when its user is destroyed" do
      user = create(:user)
      create(:like, user: user)
      expect { user.destroy }.to change(Like, :count).by(-1)
    end
  end
end
