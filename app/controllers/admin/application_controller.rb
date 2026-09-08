module Admin
  class ApplicationController < ::ApplicationController

    include NavScope
    include ContextHelpers

    before_action -> { add_breadcrumb("Admin", admin_root_path) }
    before_action :authenticate!

    layout "admin"

    # The admin identity lives in its own cookie instead of the session, because
    # the session is shared with the frontend: `rotate_session` there wipes the
    # whole jar, so a frontend login (or logout) used to sign the admin out --
    # and the admin login did the same to the frontend user. Two realms, two
    # cookies, no coupling.
    #
    # Scoped to /admin so it is not sent with public requests at all, and signed
    # so its content cannot be forged. It is a browser session cookie, i.e. it
    # lives exactly as long as the session cookie did before.
    ADMIN_COOKIE = :admin_user
    ADMIN_COOKIE_OPTIONS = {path: "/admin", httponly: true, same_site: :lax}.freeze

    private

    def authenticate!
      if current_admin_user
        true
      else
        redirect_to(new_admin_session_path)
        false
      end
    end

    def current_admin_user
      @current_admin_user ||= cookies.signed[ADMIN_COOKIE].presence
    end
    helper_method :current_admin_user

    def sign_in_admin(user_id)
      cookies.signed[ADMIN_COOKIE] = ADMIN_COOKIE_OPTIONS.merge(value: user_id)
      @current_admin_user = nil
    end

    def sign_out_admin
      cookies.delete(ADMIN_COOKIE, path: ADMIN_COOKIE_OPTIONS[:path])
      @current_admin_user = nil
    end

  end
end
