class ApplicationController < ActionController::Base

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # --------------------------------------------------------------------------
  # Current user / Authentication
  # --------------------------------------------------------------------------

  def current_user
    @current_user ||= User.from_session(session[:current_user])
  end

  helper_method :current_user

  def sign_in(user)
    return_to = session[:return_to]

    rotate_session

    session[:return_to] = return_to if return_to
    session[:current_user] = user.to_session
    @current_user = nil
  end

  def sign_out
    rotate_session
    @current_user = nil
  end

  # Every change of identity gets a new session id and discards whatever the old
  # session held. With the cookie store that is mostly hygiene -- a cookie an
  # attacker planted beforehand never carries the signed-in state afterwards,
  # because that state is only ever written to the cookie the victim's browser
  # receives. It is what keeps the login safe from session fixation should the
  # session ever be moved to a server side store.
  #
  # List filters survive the rotation: they are a UI preference, not session
  # state, and logging in or out must not throw a list's settings away. Carrying
  # them over is safe because `Filterable` casts and validates every value on
  # read, so nothing can be smuggled in that an ordinary request could not set.
  def rotate_session
    filters = session.to_hash.select { |key, _| key.to_s.end_with?("/filter") }

    reset_session

    filters.each { |key, value| session[key] = value }
  end

  def authenticate_user!
    return true if current_user

    store_return_to
    redirect_to new_session_path, alert: t("application.authentication.login_required")
    false
  end

  # Only remember GET (and HEAD, which Rails routes like GET) requests as return
  # target, and only genuinely relative paths: "//host" is routable (the router
  # collapses leading slashes) but is a protocol-relative URL, and a backslash is
  # normalised to a slash by browsers while Rails refuses to redirect to it at all.
  def store_return_to
    return unless request.get? || request.head?

    path = return_to_path.to_s
    return unless path.start_with?("/") && !path.start_with?("//") && !path.include?("\\")

    session[:return_to] = path
  end

  # Where to send the user after a successful login. Controllers override this
  # when the requested URL does not work as a landing page on its own.
  def return_to_path
    request.fullpath
  end

  # --------------------------------------------------------------------------
  # Locale
  # --------------------------------------------------------------------------

  # For each request set the locale
  before_action -> { I18n.locale = current_locale if helpers.locale_switching_enabled? }

  # Gets the current locale from the cookie or if no cookie was set from the browser settings.
  # If the browser locale is other than the default locale, :en will be used.
  def current_locale
    cookie_locale = cookies["#{application_cookie_prefix}_locale"]&.to_sym

    browser_locale = request.env["HTTP_ACCEPT_LANGUAGE"]&.scan(/^[a-z]{2}/)&.first&.to_sym
    browser_locale = :en if browser_locale != I18n.default_locale

    I18n.available_locales.find { |l| l == cookie_locale } ||
      I18n.available_locales.find { |l| l == browser_locale } ||
      I18n.default_locale
  end

  # Make the current_locale method available in views
  helper_method :current_locale

  # Helper to store the selected locale in a cookie
  # Used by the LocalesController
  def store_locale_cookie(locale)
    cookies["#{application_cookie_prefix}_locale"] = {
      value: locale,
      expires: 1.year.from_now
    }
  end

  # --------------------------------------------------------------------------
  # Breadcrumb
  # --------------------------------------------------------------------------

  def breadcrumb
    @breadcrumb ||= []
  end

  helper_method :breadcrumb

  def add_breadcrumb(label, path = nil)
    breadcrumb << {label: label, path: path}
  end

  # --------------------------------------------------------------------------
  # Utils
  # --------------------------------------------------------------------------

  def application_name
    Rails.application.class.module_parent_name
  end

  def application_cookie_prefix
    "_#{application_name.underscore}"
  end

end
