require "rails_helper"

# F-2.7. Password reset — the generator provides the flow; these specs assert
# the outcomes that matter for us.
RSpec.describe "Password reset" do
  describe "GET /passwords/new" do
    it "renders the forgot-password form" do
      get new_password_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Forgot your password")
    end
  end

  describe "POST /passwords" do
    it "redirects to sign in with a notice regardless of whether the address exists" do
      post passwords_path, params: { email_address: "nobody@example.com" }

      expect(response).to redirect_to(new_session_path)
      expect(flash[:notice]).to include("Password reset instructions sent")
    end

    it "enqueues a reset email for a known address" do
      create(:user, email_address: "ada@example.com")

      expect {
        post passwords_path, params: { email_address: "ada@example.com" }
      }.to have_enqueued_mail(PasswordsMailer, :reset)
    end

    it "does not enqueue anything for an unknown address" do
      expect {
        post passwords_path, params: { email_address: "nobody@example.com" }
      }.not_to have_enqueued_mail(PasswordsMailer, :reset)
    end
  end

  describe "the full reset flow" do
    it "lets a user set a new password via a valid token" do
      user = create(:user, email_address: "ada@example.com")
      token = user.password_reset_token

      get edit_password_path(token)
      expect(response).to have_http_status(:ok)

      patch password_path(token), params: { password: "new-sekrit-password",
                                            password_confirmation: "new-sekrit-password" }

      expect(response).to redirect_to(new_session_path)
      expect(flash[:notice]).to include("Password has been reset")

      found = User.authenticate_by(email_address: "ada@example.com",
                                   password: "new-sekrit-password")
      expect(found).to eq(user)
    end

    # Existing sessions should be killed when the password changes, so a
    # stolen session can't outlive a reset.
    it "destroys all existing sessions after a successful reset" do
      user = create(:user)
      user.sessions.create!
      user.sessions.create!
      token = user.password_reset_token

      patch password_path(token), params: { password: "new-sekrit-password",
                                            password_confirmation: "new-sekrit-password" }

      expect(user.sessions.count).to eq(0)
    end

    it "rejects mismatched password and confirmation" do
      user = create(:user)
      token = user.password_reset_token

      patch password_path(token), params: { password: "new-sekrit-password",
                                            password_confirmation: "something-else" }

      expect(response).to redirect_to(edit_password_path(token))
      expect(flash[:alert]).to include("did not match")
    end

    it "rejects an invalid or expired token" do
      get edit_password_path("bogus-token")

      expect(response).to redirect_to(new_password_path)
      expect(flash[:alert]).to include("invalid or has expired")
    end
  end
end
