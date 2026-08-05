require "rails_helper"

RSpec.describe "Profiles" do
  describe "GET /@username" do
    # F-2.5 — reading a profile never requires an account.
    it "renders for a signed-out visitor" do
      create(:user, username: "ada")

      get profile_path("ada")

      expect(response).to have_http_status(:ok)
    end

    it "shows the display name, handle and bio" do
      create(:user, username: "ada", display_name: "Ada Lovelace", bio: "First programmer.")

      get profile_path("ada")

      expect(response.body).to include("Ada Lovelace")
      expect(response.body).to include("@ada")
      expect(response.body).to include("First programmer.")
    end

    it "falls back to the username when no display name is set" do
      create(:user, username: "ada", display_name: nil)

      get profile_path("ada")

      expect(response.body).to include("ada")
    end

    # F-4.3 — the profile lists that user's posts only, newest first.
    it "lists only that user's posts, newest first" do
      ada = create(:user, username: "ada")
      create(:post, user: ada, body: "older post", created_at: 2.hours.ago)
      create(:post, user: ada, body: "newer post", created_at: 1.hour.ago)
      create(:post, body: "someone else entirely")

      get profile_path("ada")

      expect(response.body).to include("older post")
      expect(response.body).to include("newer post")
      expect(response.body).not_to include("someone else entirely")
      expect(response.body.index("newer post")).to be < response.body.index("older post")
    end

    it "shows an empty state for a user with no posts" do
      create(:user, username: "ada")

      get profile_path("ada")

      expect(response.body).to include("No posts yet")
    end

    # Usernames are stored lower-cased, so however the link was written, it
    # lands on the same profile.
    it "is reachable however the username is capitalised in the URL" do
      create(:user, username: "ada")

      get profile_path("ADA")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("@ada")
    end

    it "404s for a username nobody holds" do
      get profile_path("nobody")

      expect(response).to have_http_status(:not_found)
    end

    it "paginates posts across pages" do
      ada = create(:user, username: "ada")
      create_list(:post, ProfileFeed::PAGE_SIZE + 1, user: ada)

      get profile_path("ada")

      expect(response.body.scan(/class="post"/).size).to eq(ProfileFeed::PAGE_SIZE)
      expect(response.body).to include("Load more")

      get profile_path("ada", page: 1)

      expect(response.body.scan(/class="post"/).size).to eq(1)
    end

    # Three examples rather than one signing in three times: sign-in is a
    # no-op when a session already exists (redirect_if_authenticated), so a
    # second sign_in in the same example silently stays the first user.
    it "does not offer the edit link to a signed-out visitor" do
      create(:user, username: "ada")

      get profile_path("ada")

      expect(response.body).not_to include("Edit profile")
    end

    it "does not offer the edit link on someone else's profile" do
      create(:user, username: "ada")
      sign_in(create(:user, username: "grace"))

      get profile_path("ada")

      expect(response.body).not_to include("Edit profile")
    end

    it "offers the edit link to the owner" do
      sign_in(create(:user, username: "ada"))

      get profile_path("ada")

      expect(response.body).to include("Edit profile")
    end
  end

  describe "GET /profile/edit" do
    it "sends a signed-out visitor to sign in" do
      get edit_profile_path

      expect(response).to redirect_to(new_session_path)
    end

    it "renders the signed-in user's own profile form" do
      sign_in(create(:user, username: "ada"))

      get edit_profile_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("@ada")
    end
  end

  describe "PATCH /profile" do
    it "refuses a signed-out visitor" do
      patch update_profile_path, params: { user: { display_name: "Nobody" } }

      expect(response).to redirect_to(new_session_path)
    end

    # F-4.4. There is no id in the route, so "whose profile" is answered by the
    # session alone — a route to anyone else's does not exist (F-4.5).
    it "updates the signed-in user's display name and bio" do
      user = sign_in(create(:user, username: "ada"))

      patch update_profile_path, params: { user: { display_name: "Ada Lovelace", bio: "First programmer." } }

      expect(response).to redirect_to(profile_path("ada"))
      expect(user.reload.display_name).to eq("Ada Lovelace")
      expect(user.reload.bio).to eq("First programmer.")
    end

    # F-4.6 / ADR 0007 — usernames are changeable but unique.
    it "updates the signed-in user's username" do
      user = sign_in(create(:user, username: "ada"))

      patch update_profile_path, params: { user: { username: "ada_lovelace" } }

      expect(response).to redirect_to(profile_path("ada_lovelace"))
      expect(user.reload.username).to eq("ada_lovelace")
    end

    it "rejects a username already taken by another user" do
      create(:user, username: "grace")
      sign_in(create(:user, username: "ada"))

      patch update_profile_path, params: { user: { username: "grace" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("already been taken")
    end

    # The rejected value must not leak into the application shell: the sidebar
    # renders the signed-in identity, and showing the name that was refused
    # makes it look as though the account is now someone else's.
    it "still shows the signed-in user's own handle after a rejected rename" do
      create(:user, username: "grace")
      sign_in(create(:user, username: "ada"))

      patch update_profile_path, params: { user: { username: "grace" } }

      expect(response.body).to include(profile_path("ada"))
      expect(response.body).not_to include(profile_path("grace"))
    end

    it "rejects a bio over the limit and re-renders the form" do
      sign_in(create(:user, username: "ada"))

      patch update_profile_path, params: { user: { bio: "b" * (User::MAX_BIO_LENGTH + 1) } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Bio is too long")
    end
  end
end
