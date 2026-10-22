class LocalesController < ApplicationController

  def switch
    requested = params[:locale].to_s.strip.to_sym
    locale = I18n.available_locales.find { |l| l == requested } || I18n.default_locale
    store_locale_cookie(locale)

    redirect_back_or_to(root_path)
  end

end
