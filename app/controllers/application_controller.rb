class ApplicationController < ActionController::Base

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # --------------------------------------------------------------------------
  # Current user / Authentication
  # --------------------------------------------------------------------------

  def current_user
    # TODO: Implement current_user
    nil
  end

  helper_method :current_user

  # --------------------------------------------------------------------------
  # Locale
  # --------------------------------------------------------------------------

  # For each request set the locale
  before_action -> { I18n.locale = current_locale if helpers.locale_switching_enabled? }

  # Gets the current locale from the cookie or if no cookie was set from the browser settings.
  # If the browser locale is other than the default locale, :en will be used.
  def current_locale
    cookie_locale = cookies["#{application_cookie_prefix}_locale"]&.to_sym

    browser_locale = request.env["HTTP_ACCEPT_LANGUAGE"].scan(/^[a-z]{2}/).first&.to_sym
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
