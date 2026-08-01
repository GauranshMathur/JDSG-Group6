require "rails_helper"

# F-3.2, F-3.3, F-3.4, F-3.5. Editing and deleting your own posts, and — the
# part worth the most attention — not anyone else's.
#
# Authorisation here is by scoping (F-3.5): every write loads the post through
# Current.user.posts, so another account's row is not found and raises. These
# specs assert the outcome rather than the mechanism, so they keep their value
# if the implementation changes.
RSpec.describe "Post ownership" do
  let(:author) { create(:user) }
  let(:someone_else) { create(:user) }

  # F-3.2
  describe "editing" do
    it "shows the author the edit form for their own post" do
      post_record = create(:post, user: author, body: "mine")
      sign_in(author)

      get edit_post_path(post_record)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("mine")
    end

    it "updates the post and redirects for an HTML request" do
      post_record = create(:post, user: author, body: "before")
      sign_in(author)

      patch post_path(post_record), params: { post: { body: "after" } }

      expect(response).to redirect_to(posts_path)
      expect(post_record.reload.body).to eq("after")
    end

    it "re-renders the form when the edit is invalid" do
      post_record = create(:post, user: author, body: "before")
      sign_in(author)

      patch post_path(post_record), params: { post: { body: "" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(post_record.reload.body).to eq("before")
    end
  end

  # F-3.3
  describe "deleting" do
    it "deletes the author's own post" do
      post_record = create(:post, user: author)
      sign_in(author)

      expect { delete post_path(post_record) }.to change(Post, :count).by(-1)
      expect(response).to redirect_to(posts_path)
    end

    it "responds with a turbo stream that removes the post" do
      post_record = create(:post, user: author)
      sign_in(author)

      delete post_path(post_record), as: :turbo_stream

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('action="remove"')
    end
  end

  # F-3.4, F-3.5. The cases that would matter if this were real.
  describe "someone else's post" do
    let!(:post_record) { create(:post, user: author, body: "not yours") }

    before { sign_in(someone_else) }

    it "cannot be opened for editing" do
      get edit_post_path(post_record)

      expect(response).to have_http_status(:not_found)
    end

    it "cannot be updated" do
      patch post_path(post_record), params: { post: { body: "hijacked" } }

      expect(response).to have_http_status(:not_found)
      expect(post_record.reload.body).to eq("not yours")
    end

    it "cannot be deleted" do
      expect { delete post_path(post_record) }.not_to change(Post, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

  # F-2.6
  describe "when signed out" do
    let!(:post_record) { create(:post, user: author, body: "not yours") }

    it "cannot open the edit form" do
      get edit_post_path(post_record)

      expect(response).to redirect_to(new_session_path)
    end

    it "cannot update" do
      patch post_path(post_record), params: { post: { body: "hijacked" } }

      expect(response).to redirect_to(new_session_path)
      expect(post_record.reload.body).to eq("not yours")
    end

    it "cannot delete" do
      expect { delete post_path(post_record) }.not_to change(Post, :count)

      expect(response).to redirect_to(new_session_path)
    end
  end

  # F-3.4
  describe "the controls in the feed" do
    it "offers edit and delete on the reader's own posts" do
      create(:post, user: author, body: "mine")
      sign_in(author)

      get posts_path

      expect(response.body).to include("Edit")
      expect(response.body).to include("Delete")
    end

    it "offers neither on anyone else's" do
      create(:post, user: author, body: "theirs")
      sign_in(someone_else)

      get posts_path

      expect(response.body).not_to include(">Edit</a>")
      expect(response.body).not_to include(">Delete</button>")
    end

    it "offers neither to a signed-out visitor" do
      create(:post, user: author, body: "theirs")

      get posts_path

      expect(response.body).not_to include(">Edit</a>")
      expect(response.body).not_to include(">Delete</button>")
    end
  end
end
