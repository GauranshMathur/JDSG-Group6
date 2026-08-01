require "rails_helper"

# F-4.1. The sidebar is the application shell — it renders on every page and
# provides navigation between the feed, the user's profile, and signing in or
# out. These specs assert the navigation links, not the layout or styling.
RSpec.describe "Sidebar navigation" do
  describe "when signed out" do
    it "shows a link to the feed" do
      get posts_path

      expect(response.body).to include(">Feed</a>")
    end

    it "shows a sign-in link" do
      get posts_path

      expect(response.body).to include(">Sign in</a>")
    end

    it "shows a sign-up link" do
      get posts_path

      expect(response.body).to include(">Sign up</a>")
    end

    it "does not show a profile link" do
      get posts_path

      expect(response.body).not_to include(">Profile</a>")
    end

    it "does not show a sign-out button" do
      get posts_path

      expect(response.body).not_to include("Sign out")
    end
  end

  describe "when signed in" do
    let(:user) { create(:user, username: "ada") }

    before { sign_in(user) }

    it "shows a link to the feed" do
      get posts_path

      expect(response.body).to include(">Feed</a>")
    end

    it "shows a link to the user's own profile" do
      get posts_path

      expect(response.body).to include(profile_path("ada"))
      expect(response.body).to include(">Profile</a>")
    end

    it "shows the user's name and handle" do
      get posts_path

      expect(response.body).to include("@ada")
    end

    it "shows a sign-out button" do
      get posts_path

      expect(response.body).to include("Sign out")
    end

    it "does not show sign-in or sign-up links" do
      get posts_path

      expect(response.body).not_to include(">Sign in</a>")
      expect(response.body).not_to include(">Sign up</a>")
    end
  end

  # The sidebar renders on non-feed pages too.
  it "renders on profile pages" do
    create(:user, username: "ada")

    get profile_path("ada")

    expect(response.body).to include(">Feed</a>")
    expect(response.body).to include(">Sign in</a>")
  end
end
