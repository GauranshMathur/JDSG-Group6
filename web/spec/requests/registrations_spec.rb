require "rails_helper"

RSpec.describe "Registrations" do
  let(:valid_params) do
    { user: { username: "ada",
              email_address: "ada@example.com",
              password: "sekrit-password",
              password_confirmation: "sekrit-password" } }
  end

  describe "GET /registration/new" do
    it "renders the sign-up form for a visitor" do
      get new_registration_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Create an account")
    end

    it "redirects someone who is already signed in" do
      sign_in

      get new_registration_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /registration" do
    it "creates an account" do
      expect { post registration_path, params: valid_params }.to change(User, :count).by(1)
    end

    it "signs the new account in and returns to the feed" do
      post registration_path, params: valid_params

      expect(response).to redirect_to(root_url)
      expect(Session.count).to eq(1)
    end

    # F-4.2/F-4.6 — the username is claimed here, and only here.
    it "sets the chosen username" do
      post registration_path, params: valid_params

      expect(User.last.username).to eq("ada")
    end

    it "rejects a username someone already holds, whatever the case" do
      create(:user, username: "ada")
      params = valid_params.deep_merge(user: { username: "ADA" })

      expect { post registration_path, params: params }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a username with characters outside letters, numbers and underscores" do
      params = valid_params.deep_merge(user: { username: "ada!" })

      expect { post registration_path, params: params }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a duplicate email address" do
      create(:user, email_address: "ada@example.com")

      expect { post registration_path, params: valid_params }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a duplicate email address differing only in case" do
      create(:user, email_address: "ADA@example.com")

      expect { post registration_path, params: valid_params }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "re-renders the form with errors when the password is too short" do
      params = valid_params.deep_merge(user: { password: "short", password_confirmation: "short" })

      post registration_path, params: params

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Password is too short")
    end

    it "does not create an account when the confirmation does not match" do
      params = valid_params.deep_merge(user: { password_confirmation: "something-else" })

      expect { post registration_path, params: params }.not_to change(User, :count)
    end
  end
end
