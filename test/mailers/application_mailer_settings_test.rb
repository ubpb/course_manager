require "test_helper"

# Every server may set the delivery method and the host used in links in its
# config/application.yml; a test system delivers to letter_opener_web and links
# to itself. Without settings, the defaults of the environment stay.
class ApplicationMailerSettingsTest < ActiveSupport::TestCase

  # A subclass per test, so the settings don't leak into the real mailers.
  def mailer_with(settings)
    mailer = Class.new(ApplicationMailer)
    mailer.apply_server_settings(->(*keys, **) { settings[keys] })
    mailer
  end

  test "without settings the defaults of the environment stay" do
    mailer = mailer_with({})

    assert_equal ApplicationMailer.delivery_method, mailer.delivery_method
    assert_equal ApplicationMailer.default_url_options, mailer.default_url_options
  end

  test "a test system delivers to letter_opener_web" do
    mailer = mailer_with({[:mail, :delivery_method] => "letter_opener_web"})

    assert_equal :letter_opener_web, mailer.delivery_method
  end

  test "links in mails point to the configured host" do
    mailer = mailer_with({[:mail, :host] => "stage.ub.uni-paderborn.de"})

    assert_equal "stage.ub.uni-paderborn.de", mailer.default_url_options[:host]
  end

end
