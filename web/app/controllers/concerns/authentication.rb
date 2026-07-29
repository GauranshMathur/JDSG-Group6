module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    # eager_load rather than includes: with find_by, includes preloads in a
    # second query, which is the round trip this is trying to avoid. eager_load
    # forces a single LEFT JOIN.
    #
    # Almost every authenticated request reads Current.user — the masthead alone
    # does — so fetching the user lazily costs an extra round trip on all of
    # them. See docs/latency.md.
    def find_session_by_cookie
      Session.eager_load(:user).find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to new_session_path
    end

    # For the sign-in and sign-up pages, which have nothing to offer someone who
    # is already signed in.
    def redirect_if_authenticated
      redirect_to root_path if authenticated?
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
      end
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
    end
end
