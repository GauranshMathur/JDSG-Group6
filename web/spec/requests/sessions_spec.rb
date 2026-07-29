require "rails_helper"

RSpec.describe "Sessions" do
  describe "GET /session/new" do
    it "renders the sign-in form" do
      get new_session_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sign in")
    end

    it "redirects someone who is already signed in" do
      sign_in

      get new_session_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /session" do
    it "signs in with the right password" do
      user = create(:user, email_address: "ada@example.com")

      post session_path, params: { email_address: "ada@example.com",
                                   password: AuthenticationHelpers::DEFAULT_PASSWORD }

      expect(response).to redirect_to(root_url)
      expect(user.sessions.count).to eq(1)
    end

    it "signs in regardless of the case the address is typed in" do
      user = create(:user, email_address: "ada@example.com")

      post session_path, params: { email_address: "ADA@EXAMPLE.COM",
                                   password: AuthenticationHelpers::DEFAULT_PASSWORD }

      expect(user.sessions.count).to eq(1)
    end

    it "refuses the wrong password without creating a session" do
      create(:user, email_address: "ada@example.com")

      post session_path, params: { email_address: "ada@example.com", password: "wrong-password" }

      expect(response).to redirect_to(new_session_path)
      expect(Session.count).to eq(0)
    end

    it "refuses an unknown address without disclosing that it is unknown" do
      post session_path, params: { email_address: "nobody@example.com", password: "whatever-it-is" }

      expect(flash[:alert]).to eq("Try another email address or password.")
    end
  end

  describe "DELETE /session" do
    # F-2.4. The session record is destroyed, not merely the cookie, so a stolen
    # cookie is worthless after sign-out.
    it "revokes the session server-side" do
      user = sign_in

      expect { delete session_path }.to change { user.sessions.count }.from(1).to(0)
    end

    it "leaves the visitor signed out" do
      sign_in
      delete session_path

      get posts_path

      expect(response.body).to include("to post.")
    end

    it "requires a session to sign out of" do
      delete session_path

      expect(response).to redirect_to(new_session_path)
    end
  end
end
