class LocalesController < ApplicationController

  def switch
    locale = I18n.available_locales.find { |l| l == params[:locale]&.to_s&.strip&.to_sym } || I18n.default_locale
    store_locale_cookie(locale)

    redirect_back fallback_location: root_path
  end

end
