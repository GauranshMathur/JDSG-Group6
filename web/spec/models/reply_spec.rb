require "rails_helper"

# F-5.10, F-5.12
RSpec.describe "Post replies" do
  describe "parent association" do
    it "allows a post to have a parent" do
      parent = create(:post)
      reply = create(:post, parent: parent)

      expect(reply.parent).to eq(parent)
    end

    it "allows a post without a parent (top-level)" do
      post = create(:post)

      expect(post.parent).to be_nil
    end

    it "tracks direct replies through the replies association" do
      parent = create(:post)
      reply = create(:post, parent: parent)

      expect(parent.replies).to include(reply)
    end

    it "allows a reply to a reply" do
      grandparent = create(:post)
      parent = create(:post, parent: grandparent)
      child = create(:post, parent: parent)

      expect(parent.replies).to include(child)
    end
  end

  describe "counter cache" do
    it "increments the parent's replies_count on create" do
      parent = create(:post)
      expect { create(:post, parent: parent) }
        .to change { parent.reload.replies_count }.from(0).to(1)
    end

    it "decrements the parent's replies_count on destroy" do
      parent = create(:post)
      reply = create(:post, parent: parent)
      expect { reply.destroy }
        .to change { parent.reload.replies_count }.from(1).to(0)
    end
  end

  describe "dependent destroy" do
    it "destroys replies when the parent post is destroyed" do
      parent = create(:post)
      create(:post, parent: parent)

      expect { parent.destroy }.to change(Post, :count).by(-2)
    end
  end

  describe "top_level scope" do
    it "returns only posts without a parent" do
      top_level = create(:post)
      parent = create(:post)
      create(:post, parent: parent)

      expect(Post.top_level).to include(top_level, parent)
      expect(Post.top_level.count).to eq(2)
    end
  end
end
