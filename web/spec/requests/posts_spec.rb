require "rails_helper"

RSpec.describe "Posts" do
  describe "GET /posts" do
    # F-2.5. The timeline is readable without an account, which is the 90 in the
    # 90-9-1 rule — see docs/design-principles.md.
    it "renders the feed" do
      get posts_path

      expect(response).to have_http_status(:ok)
    end

    it "shows a signed-out visitor a prompt instead of the composer" do
      get posts_path

      expect(response.body).to include("to post.")
      expect(response.body).not_to include("What&#39;s happening?")
    end

    it "shows a signed-in user the composer" do
      sign_in

      get posts_path

      expect(response.body).to include("What&#39;s happening?")
    end

    it "shows existing posts with their author's handle linking to the profile" do
      create(:post, body: "hello world", user: create(:user, username: "ada"))

      get posts_path

      expect(response.body).to include("hello world")
      expect(response.body).to include("@ada")
      expect(response.body).to include(profile_path("ada"))
    end

    it "shows the empty state when there are no posts" do
      get posts_path

      expect(response.body).to include("Nothing here yet")
    end

    it "returns at most one page of posts" do
      create_list(:post, PostsController::PAGE_SIZE + 5)

      get posts_path

      expect(response.body.scan(/class="post"/).size).to eq(PostsController::PAGE_SIZE)
    end

    it "offers a load-older link when the timeline is longer than one page" do
      create_list(:post, PostsController::PAGE_SIZE + 1)

      get posts_path

      expect(response.body).to include("Load older posts")
    end

    it "omits the load-older link on the last page" do
      create_list(:post, 3)

      get posts_path

      expect(response.body).not_to include("Load older posts")
    end

    it "returns older posts when given a cursor" do
      newest = create(:post, body: "newest", created_at: 1.minute.ago)
      create(:post, body: "oldest", created_at: 2.minutes.ago)

      get posts_path(after: newest.cursor)

      expect(response.body).to include("oldest")
      expect(response.body).not_to include("newest")
    end

    it "falls back to the first page when the cursor is malformed" do
      create(:post, body: "hello world")

      get posts_path(after: "not-a-cursor")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("hello world")
    end

    # "not-a-cursor" above has no comma, so it is rejected before the timestamp
    # is ever parsed. This one has the right shape and an unparseable timestamp,
    # which is the case that used to render an empty feed.
    it "falls back to the first page when only the cursor timestamp is malformed" do
      create(:post, body: "hello world")

      get posts_path(after: "garbage,42")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("hello world")
    end
  end

  describe "POST /posts" do
    # F-2.6. Writing needs an account; F-2.5 keeps reading open to everyone.
    context "when signed out" do
      it "refuses to create a post and sends the visitor to sign in" do
        expect {
          post posts_path, params: { post: { body: "a new post" } }
        }.not_to change(Post, :count)

        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when signed in" do
      let(:current_user) { create(:user) }

      before { sign_in(current_user) }

      it "creates a post and redirects for an HTML request" do
        expect {
          post posts_path, params: { post: { body: "a new post" } }
        }.to change(Post, :count).by(1)

        expect(response).to redirect_to(posts_path)
      end

      it "responds with a turbo stream that prepends the post" do
        post posts_path,
             params: { post: { body: "a new post" } },
             as: :turbo_stream

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("a new post")
        expect(response.body).to include('action="prepend"')
        expect(response.body).to include('target="timeline"')
      end

      it "attributes the post to the signed-in account" do
        post posts_path, params: { post: { body: "a new post" } }

        expect(Post.last.user).to eq(current_user)
      end

      # Authorship comes from the session, so a supplied user_id must not win.
      it "ignores a user_id supplied in the parameters" do
        someone_else = create(:user)

        post posts_path, params: { post: { body: "a new post", user_id: someone_else.id } }

        expect(Post.last.user).to eq(current_user)
      end

      it "rejects an empty body and re-renders the feed" do
        expect {
          post posts_path, params: { post: { body: "" } }
        }.not_to change(Post, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Body can&#39;t be blank")
      end

      it "rejects a body over the length limit" do
        expect {
          post posts_path, params: { post: { body: "a" * (Post::MAX_BODY_LENGTH + 1) } }
        }.not_to change(Post, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "still renders the timeline when the submission fails" do
        create(:post, body: "an existing post")

        post posts_path, params: { post: { body: "" } }

        expect(response.body).to include("an existing post")
      end
    end
  end
end
