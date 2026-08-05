require "rails_helper"

# F-4.1. The sidebar is the application shell — it renders on every page and
# provides navigation between the feed, the user's profile, and signing in or
# out. These specs assert the navigation links, not the layout or styling.
RSpec.describe "Sidebar navigation" do
  describe "when signed out" do
    it "shows a link to the feed" do
      get posts_path

      expect(response.body).to include(">Feed</span>")
    end

    it "shows a sign-in link" do
      get posts_path

      expect(response.body).to include(">Sign in</span>")
    end

    it "shows a sign-up link" do
      get posts_path

      expect(response.body).to include(">Sign up</span>")
    end

    it "does not show a profile link" do
      get posts_path

      expect(response.body).not_to include(">Profile</span>")
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

      expect(response.body).to include(">Feed</span>")
    end

    it "shows a link to the user's own profile" do
      get posts_path

      expect(response.body).to include(profile_path("ada"))
      expect(response.body).to include(">Profile</span>")
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

      expect(response.body).not_to include(">Sign in</span>")
      expect(response.body).not_to include(">Sign up</span>")
    end
  end

  # The sidebar renders on non-feed pages too.
  it "renders on profile pages" do
    create(:user, username: "ada")

    get profile_path("ada")

    expect(response.body).to include(">Feed</span>")
    expect(response.body).to include(">Sign in</span>")
  end

  # F-4.7 — the logo is the way back to the feed from anywhere.
  describe "the brand logo" do
    it "renders the logo as a link to the feed" do
      get posts_path

      expect(response.body).to match(%r{<a[^>]*class="sidebar__brand"[^>]*href="/"|<a[^>]*href="/"[^>]*class="sidebar__brand"})
      expect(response.body).to include("twitter-logo")
    end

    it "gives the logo an accessible name rather than leaving it a bare image" do
      get posts_path

      expect(response.body).to include('alt="Twitter Clone — go to the feed"')
    end

    it "is present on pages other than the feed" do
      create(:user, username: "ada")

      get profile_path("ada")

      expect(response.body).to include("sidebar__brand")
    end
  end

  # F-4.8 — the sidebar collapses to a rail so the reading column gets the width.
  describe "the collapse toggle" do
    it "renders a toggle button wired to the sidebar controller" do
      get posts_path

      expect(response.body).to include("sidebar__toggle")
      expect(response.body).to include("sidebar#toggle")
    end

    it "marks the toggle up for assistive technology" do
      get posts_path

      expect(response.body).to include('aria-controls="sidebar-nav"')
      expect(response.body).to include('id="sidebar-nav"')
      expect(response.body).to match(/aria-expanded="(true|false)"/)
    end

    it "labels the nav items so they stay identifiable when collapsed to icons" do
      sign_in(create(:user, username: "ada"))

      get posts_path

      expect(response.body).to include('title="Feed"')
      expect(response.body).to include('title="Search"')
      expect(response.body).to include('title="Profile"')
    end
  end
end
