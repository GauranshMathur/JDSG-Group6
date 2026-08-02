require "rails_helper"

# F-5.8, F-5.9
RSpec.describe Repost do
  describe "validations" do
    it "requires a user and a post" do
      repost = Repost.new
      expect(repost).not_to be_valid
      expect(repost.errors[:user]).to be_present
      expect(repost.errors[:post]).to be_present
    end

    it "prevents the same user from reposting the same post twice" do
      existing = create(:repost)
      duplicate = build(:repost, user: existing.user, post: existing.post)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
    end

    it "allows different users to repost the same post" do
      post_record = create(:post)
      create(:repost, post: post_record)
      second = build(:repost, post: post_record)
      expect(second).to be_valid
    end
  end

  describe "counter cache" do
    it "increments the post's reposts_count on create" do
      post_record = create(:post)
      expect { create(:repost, post: post_record) }
        .to change { post_record.reload.reposts_count }.from(0).to(1)
    end

    it "decrements the post's reposts_count on destroy" do
      repost = create(:repost)
      post_record = repost.post
      expect { repost.destroy }
        .to change { post_record.reload.reposts_count }.from(1).to(0)
    end
  end

  describe "dependent destroy" do
    it "is destroyed when its post is destroyed" do
      repost = create(:repost)
      expect { repost.post.destroy }.to change(Repost, :count).by(-1)
    end

    it "is destroyed when its user is destroyed" do
      user = create(:user)
      create(:repost, user: user)
      expect { user.destroy }.to change(Repost, :count).by(-1)
    end
  end
end
