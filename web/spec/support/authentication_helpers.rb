# Signs in through the real sign-in endpoint rather than by setting the session
# cookie directly, so request specs exercise the same path a browser takes.
module AuthenticationHelpers
  DEFAULT_PASSWORD = "sekrit-password".freeze

  def sign_in(user = create(:user), password: DEFAULT_PASSWORD)
    post session_path, params: { email_address: user.email_address, password: password }
    user
  end
end
