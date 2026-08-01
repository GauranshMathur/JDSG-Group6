require "rails_helper"

# F-5.6, F-5.7
RSpec.describe "Likes" do
  let(:user) { create(:user) }
  let(:post_record) { create(:post) }

  describe "POST /posts/:post_id/like" do
    context "when signed in" do
      before { sign_in(user) }

      it "creates a like and increments the count" do
        expect { post post_like_path(post_record) }
          .to change(Like, :count).by(1)

        expect(post_record.reload.likes_count).to eq(1)
      end

      it "responds with a turbo stream that replaces the like button" do
        post post_like_path(post_record), as: :turbo_stream

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include('action="replace"')
        expect(response.body).to include("like_post_#{post_record.id}")
      end

      it "redirects for an HTML request" do
        post post_like_path(post_record)

        expect(response).to redirect_to(posts_path)
      end

      it "is idempotent — liking twice does not create a duplicate" do
        create(:like, user: user, post: post_record)

        expect { post post_like_path(post_record) }
          .not_to change(Like, :count)
      end
    end

    context "when signed out" do
      it "redirects to sign in" do
        post post_like_path(post_record)

        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe "DELETE /posts/:post_id/like" do
    context "when signed in" do
      before { sign_in(user) }

      it "destroys the like and decrements the count" do
        create(:like, user: user, post: post_record)

        expect { delete post_like_path(post_record) }
          .to change(Like, :count).by(-1)

        expect(post_record.reload.likes_count).to eq(0)
      end

      it "responds with a turbo stream that replaces the like button" do
        create(:like, user: user, post: post_record)

        delete post_like_path(post_record), as: :turbo_stream

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include('action="replace"')
        expect(response.body).to include("like_post_#{post_record.id}")
      end

      it "returns 404 when the user has not liked the post" do
        delete post_like_path(post_record)

        expect(response).to have_http_status(:not_found)
      end

      it "cannot unlike someone else's like" do
        other_user = create(:user)
        create(:like, user: other_user, post: post_record)

        delete post_like_path(post_record)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed out" do
      it "redirects to sign in" do
        delete post_like_path(post_record)

        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe "like button in the feed" do
    it "shows the like count on every post" do
      post_record = create(:post, user: user)
      create_list(:like, 3, post: post_record)

      get posts_path

      expect(response.body).to include("3")
    end

    it "shows the liked state for the signed-in user's likes" do
      sign_in(user)
      liked_post = create(:post)
      create(:like, user: user, post: liked_post)

      get posts_path

      expect(response.body).to include("like-button__toggle--liked")
    end

    it "does not show liked state for posts the user has not liked" do
      sign_in(user)
      unliked_post = create(:post)

      get posts_path

      doc = response.body
      button_html = doc[/id="like_post_#{unliked_post.id}"[^>]*>.*?<\/div>/m]
      expect(button_html).not_to include("like-button__toggle--liked") if button_html
    end
  end
end
