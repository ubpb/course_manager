module Admin
  class ApplicationController < ::ApplicationController

    include NavScope
    include ContextHelpers

    before_action :authenticate!

    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

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
      redirect_to(new_admin_session_path) unless current_admin_user
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

    # A record that is gone -- deleted in another tab, whose menu bar still
    # leads to its page, or by a colleague -- leads to the list of the area of
    # its page. A 303, so that Turbo follows a form sent for it with a GET.
    def record_not_found
      redirect_to area_list_path, alert: "Den aufgerufenen Eintrag gibt es nicht (mehr).", status: :see_other
    end

    def area_list_path
      case helpers.admin_menu_section
      when :offers then admin_offers_path(nav_scope: nil)
      when :master_data then url_for(action: :index, nav_scope: nil)
      else admin_events_path(nav_scope: nil)
      end
    end

  end
end
