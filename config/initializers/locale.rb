# Where the I18n library should search for translation files
I18n.load_path += Rails.root.glob("config/locales/**/*.{rb,yml}")

I18n.available_locales = [:de, :en]
I18n.default_locale = :de
