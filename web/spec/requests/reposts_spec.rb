require "rails_helper"

# F-5.8, F-5.9
RSpec.describe "Reposts" do
  let(:user) { create(:user) }
  let(:post_record) { create(:post) }

  describe "POST /posts/:post_id/repost" do
    context "when signed in" do
      before { sign_in(user) }

      # F-5.8
      it "creates a repost and increments the count" do
        expect { post post_repost_path(post_record) }
          .to change(Repost, :count).by(1)

        expect(post_record.reload.reposts_count).to eq(1)
      end

      it "responds with a turbo stream that replaces the repost button" do
        post post_repost_path(post_record), as: :turbo_stream

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include('action="replace"')
        expect(response.body).to include("repost_post_#{post_record.id}")
      end

      it "redirects for an HTML request" do
        post post_repost_path(post_record)

        expect(response).to redirect_to(posts_path)
      end

      it "is idempotent — reposting twice does not create a duplicate" do
        create(:repost, user: user, post: post_record)

        expect { post post_repost_path(post_record) }
          .not_to change(Repost, :count)
      end
    end

    context "when signed out" do
      it "redirects to sign in" do
        post post_repost_path(post_record)

        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe "DELETE /posts/:post_id/repost" do
    context "when signed in" do
      before { sign_in(user) }

      # F-5.8
      it "destroys the repost and decrements the count" do
        create(:repost, user: user, post: post_record)

        expect { delete post_repost_path(post_record) }
          .to change(Repost, :count).by(-1)

        expect(post_record.reload.reposts_count).to eq(0)
      end

      it "responds with a turbo stream that replaces the repost button" do
        create(:repost, user: user, post: post_record)

        delete post_repost_path(post_record), as: :turbo_stream

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include('action="replace"')
        expect(response.body).to include("repost_post_#{post_record.id}")
      end

      it "returns 404 when the user has not reposted the post" do
        delete post_repost_path(post_record)

        expect(response).to have_http_status(:not_found)
      end

      it "cannot un-repost someone else's repost" do
        other_user = create(:user)
        create(:repost, user: other_user, post: post_record)

        delete post_repost_path(post_record)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed out" do
      it "redirects to sign in" do
        delete post_repost_path(post_record)

        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  # F-5.9
  describe "repost button in the feed" do
    it "shows the repost count on every post" do
      post_record = create(:post, user: user)
      create_list(:repost, 3, post: post_record)

      get posts_path

      expect(response.body).to include("3")
    end

    it "shows the reposted state for the signed-in user's reposts" do
      sign_in(user)
      reposted_post = create(:post)
      create(:repost, user: user, post: reposted_post)

      get posts_path

      expect(response.body).to include("repost-button__toggle--reposted")
    end

    it "does not show reposted state for posts the user has not reposted" do
      sign_in(user)
      unreposted_post = create(:post)

      get posts_path

      doc = response.body
      button_html = doc[/id="repost_post_#{unreposted_post.id}"[^>]*>.*?<\/div>/m]
      expect(button_html).not_to include("repost-button__toggle--reposted") if button_html
    end
  end
end
