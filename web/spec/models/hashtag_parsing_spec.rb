require "rails_helper"

# F-5.1, F-5.2, F-5.3
RSpec.describe "Hashtag parsing" do
  describe "on create" do
    it "parses hashtags from the body and creates tag associations" do
      post = create(:post, body: "Hello #rails #ruby")

      expect(post.tags.map(&:name)).to contain_exactly("rails", "ruby")
    end

    it "creates the Tag record if it does not exist" do
      expect { create(:post, body: "Hello #newtag") }
        .to change(Tag, :count).by(1)
    end

    it "reuses an existing Tag record" do
      create(:post, body: "First #rails")

      expect { create(:post, body: "Second #rails") }
        .not_to change(Tag, :count)
    end

    # F-5.3
    it "normalises tags to lower case" do
      post = create(:post, body: "Hello #Rails #RUBY")

      expect(post.tags.map(&:name)).to contain_exactly("rails", "ruby")
    end

    it "treats #Rails and #rails as the same tag" do
      create(:post, body: "#Rails is great")

      expect { create(:post, body: "#rails is great") }
        .not_to change(Tag, :count)
    end

    it "does not create tags for a post without hashtags" do
      post = create(:post, body: "no tags here")

      expect(post.tags).to be_empty
    end

    it "handles hashtags at the start, middle, and end of the body" do
      post = create(:post, body: "#start middle #middle end #end")

      expect(post.tags.map(&:name)).to contain_exactly("start", "middle", "end")
    end

    it "ignores the # character when not followed by word characters" do
      post = create(:post, body: "price is # 100")

      expect(post.tags).to be_empty
    end
  end

  describe "on update" do
    it "adds new tags when the body is edited" do
      post = create(:post, body: "#rails")

      post.update!(body: "#rails #ruby")

      expect(post.tags.map(&:name)).to contain_exactly("rails", "ruby")
    end

    it "removes tags no longer in the body" do
      post = create(:post, body: "#rails #ruby")

      post.update!(body: "#rails only")

      expect(post.tags.map(&:name)).to contain_exactly("rails")
    end
  end

  describe "dependent destroy" do
    it "destroys post_tags when the post is destroyed" do
      post = create(:post, body: "#rails")

      expect { post.destroy }.to change(PostTag, :count).by(-1)
    end

    it "does not destroy the Tag itself when a post is destroyed" do
      post = create(:post, body: "#rails")

      expect { post.destroy }.not_to change(Tag, :count)
    end
  end
end
