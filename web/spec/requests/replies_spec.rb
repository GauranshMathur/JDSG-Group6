require "rails_helper"

# F-5.10, F-5.11, F-5.12
RSpec.describe "Replies" do
  let(:user) { create(:user) }
  let!(:parent_post) { create(:post) }

  # F-5.11
  describe "GET /posts/:id (post detail page)" do
    it "shows the post and its author" do
      post_record = create(:post, body: "the original", user: create(:user, username: "ada"))

      get post_path(post_record)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("the original")
      expect(response.body).to include("@ada")
    end

    it "lists direct replies in chronological order" do
      post_record = create(:post)
      older_reply = create(:post, parent: post_record, body: "first reply", created_at: 2.minutes.ago)
      newer_reply = create(:post, parent: post_record, body: "second reply", created_at: 1.minute.ago)

      get post_path(post_record)

      body = response.body
      expect(body).to include("first reply")
      expect(body).to include("second reply")
      expect(body.index("first reply")).to be < body.index("second reply")
    end

    it "does not show replies to other posts" do
      post_record = create(:post)
      other_post = create(:post)
      create(:post, parent: other_post, body: "not here")

      get post_path(post_record)

      expect(response.body).not_to include("not here")
    end

    # F-5.12
    it "shows the reply count on the parent post" do
      post_record = create(:post)
      create_list(:post, 3, parent: post_record)

      get post_path(post_record)

      expect(response.body).to include("3")
    end

    it "shows a reply composer for signed-in users" do
      sign_in(user)

      get post_path(parent_post)

      expect(response.body).to include("Reply")
    end

    it "does not show the reply composer for signed-out visitors" do
      get post_path(parent_post)

      expect(response.body).not_to include("reply-composer")
    end

    it "shows 'replying to @username' context on each reply" do
      author = create(:user, username: "bob")
      post_record = create(:post, user: author)
      create(:post, parent: post_record, body: "a reply")

      get post_path(post_record)

      expect(response.body).to include("@bob")
    end
  end

  # F-5.10
  describe "POST /posts/:post_id/replies" do
    context "when signed in" do
      before { sign_in(user) }

      it "creates a reply and increments the reply count" do
        expect { post post_replies_path(parent_post), params: { post: { body: "my reply" } } }
          .to change(Post, :count).by(1)

        reply = Post.last
        expect(reply.parent).to eq(parent_post)
        expect(reply.user).to eq(user)
        expect(parent_post.reload.replies_count).to eq(1)
      end

      it "redirects to the parent post's detail page for an HTML request" do
        post post_replies_path(parent_post), params: { post: { body: "my reply" } }

        expect(response).to redirect_to(post_path(parent_post))
      end

      it "responds with a turbo stream that appends the reply" do
        post post_replies_path(parent_post),
             params: { post: { body: "my reply" } },
             as: :turbo_stream

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include('action="append"')
        expect(response.body).to include("my reply")
      end

      it "rejects an empty body" do
        expect {
          post post_replies_path(parent_post), params: { post: { body: "" } }
        }.not_to change(Post, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when signed out" do
      it "redirects to sign in" do
        post post_replies_path(parent_post), params: { post: { body: "my reply" } }

        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe "feed filtering" do
    it "does not show replies in the main feed" do
      top_level = create(:post, body: "top level post")
      create(:post, parent: top_level, body: "a reply that should not appear")

      get posts_path

      expect(response.body).to include("top level post")
      expect(response.body).not_to include("a reply that should not appear")
    end

    it "does not show replies on profile pages" do
      author = create(:user, username: "ada")
      top_level = create(:post, user: author, body: "top level post")
      create(:post, user: author, parent: top_level, body: "a reply that should not appear")

      get profile_path("ada")

      expect(response.body).to include("top level post")
      expect(response.body).not_to include("a reply that should not appear")
    end
  end

  # F-5.12
  describe "reply count in the feed" do
    it "shows the reply count on posts in the feed" do
      post_record = create(:post)
      create_list(:post, 2, parent: post_record)

      get posts_path

      expect(response.body).to include("2")
    end
  end
end
