require "test_helper"

# Where locale switching is enabled, a chosen language is kept in a cookie;
# without one the browser's language decides between German and English.
# Switched off -- as it is by default -- every page stays German.
class LocaleTest < ActionDispatch::IntegrationTest

  include ConfigOverride

  COOKIE = "_course_manager_locale".freeze

  def og_locale
    css_select("meta[property='og:locale']").first["content"]
  end

  def with_locale_switching(&)
    with_config(locale_switching: {enabled: true}, &)
  end

  test "choosing a language keeps it and leads back" do
    get locale_path(locale: "en"), headers: {"Referer" => "http://www.example.com/kontakt"}

    assert_redirected_to "http://www.example.com/kontakt"
    assert_equal "en", cookies[COOKIE]
  end

  test "an unknown language falls back to German, and without a way back to the home page" do
    get locale_path(locale: "fr")

    assert_redirected_to root_path
    assert_equal "de", cookies[COOKIE]
  end

  test "the chosen language wins over the browser's" do
    with_locale_switching do
      get locale_path(locale: "en")
      get root_path, headers: {"Accept-Language" => "de-DE"}

      assert_equal "en_US", og_locale
    end
  end

  test "without a choice German browsers get German and all others English" do
    with_locale_switching do
      {"de-DE,de;q=0.9" => "de_DE", "en-US" => "en_US", "fr-FR" => "en_US"}.each do |accept, locale|
        get root_path, headers: {"Accept-Language" => accept}

        assert_equal locale, og_locale, accept
      end
    end
  end

  test "switched off, every page stays German" do
    get locale_path(locale: "en")
    get root_path, headers: {"Accept-Language" => "en-US"}

    assert_equal "de_DE", og_locale
  end

  # I18n.locale belongs to the thread, which serves the next request too.
  test "a request does not leave its language to the next one" do
    with_locale_switching { get root_path, headers: {"Accept-Language" => "en-US"} }

    get root_path, headers: {"Accept-Language" => "en-US"}

    assert_equal "de_DE", og_locale
  end

end
