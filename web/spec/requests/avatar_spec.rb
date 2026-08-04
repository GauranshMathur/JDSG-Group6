require "rails_helper"

# F-7.1
RSpec.describe "Avatar upload" do
  let(:avatar_file) { fixture_file_upload("avatar.png", "image/png") }

  describe "PATCH /profile (with avatar)" do
    it "refuses a signed-out visitor" do
      patch update_profile_path, params: { user: { avatar: avatar_file } }

      expect(response).to redirect_to(new_session_path)
    end

    it "attaches an avatar to the signed-in user's profile" do
      user = sign_in(create(:user, username: "ada"))

      patch update_profile_path, params: { user: { avatar: avatar_file } }

      expect(response).to redirect_to(profile_path("ada"))
      expect(user.reload.avatar).to be_attached
    end

    it "replaces an existing avatar" do
      user = sign_in(create(:user, username: "ada"))
      user.avatar.attach(avatar_file)
      old_blob_id = user.avatar.blob.id

      new_file = fixture_file_upload("avatar.png", "image/png")
      patch update_profile_path, params: { user: { avatar: new_file } }

      expect(user.reload.avatar.blob.id).not_to eq(old_blob_id)
    end
  end

  describe "GET /@username (avatar display)" do
    it "shows the avatar on the profile page when one is attached" do
      user = create(:user, username: "ada")
      user.avatar.attach(avatar_file)

      get profile_path("ada")

      expect(response.body).to include("avatar")
    end

    it "shows the default avatar image when no avatar is attached" do
      create(:user, username: "ada")

      get profile_path("ada")

      expect(response.body).to include("default-avatar")
    end

    it "shows the default avatar in the feed for authors without one" do
      create(:post, body: "No avatar here", user: create(:user, username: "ada"))

      get posts_path

      expect(response.body).to include("default-avatar")
    end

    it "gives the fallback its size class rather than a literal \#{size}" do
      create(:user, username: "ada")

      get profile_path("ada")

      expect(response.body).to include("avatar--display")
      expect(response.body).not_to include('avatar--#')
    end
  end

  describe "GET /profile/edit (avatar field)" do
    it "shows the avatar upload field" do
      sign_in(create(:user))

      get edit_profile_path

      expect(response.body).to include("avatar")
      expect(response.body).to include('type="file"')
    end
  end
end
