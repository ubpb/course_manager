require "test_helper"

# A server keeps the application's mails for reading (letter_opener_web), as
# production.rb sets it, unless its config/application.yml lets them go out
# (mail.delivery_method: sendmail on a production machine); it may also set
# the host used in links. A value no delivery method is registered for stops
# the boot instead of the first mail.
class ApplicationMailerSettingsTest < ActiveSupport::TestCase

  include ConfigOverride

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

  test "a production machine lets its mails go out" do
    mailer = mailer_with({[:mail, :delivery_method] => "sendmail"})

    assert_equal :sendmail, mailer.delivery_method
    assert_not mailer.keeps_mails?
  end

  test "a system that keeps its mails for reading says so" do
    mailer = mailer_with({[:mail, :delivery_method] => "letter_opener_web"})

    assert_equal :letter_opener_web, mailer.delivery_method
    assert_predicate mailer, :keeps_mails?
  end

  test "an unknown delivery method stops the boot" do
    error = assert_raises(ArgumentError) { mailer_with({[:mail, :delivery_method] => "sendmial"}) }

    assert_match(/"sendmial"/, error.message)
  end

  test "links in mails point to the configured host" do
    mailer = mailer_with({[:mail, :host] => "stage.ub.uni-paderborn.de"})

    assert_equal "stage.ub.uni-paderborn.de", mailer.default_url_options[:host]
  end

  # In a child process: loading the file again here would also reset what the
  # coverage counted for it.
  test "the mailer applies the server's settings when it loads" do
    pid = fork do
      with_config(mail: {delivery_method: "sendmail"}) { load Rails.root.join("app/mailers/application_mailer.rb") }
      exit!(ApplicationMailer.delivery_method == :sendmail ? 0 : 1)
    end
    Process.wait(pid)

    assert_predicate $CHILD_STATUS, :success?
  end

  # config/routes.rb mounts the viewer where this holds.
  test "the viewer is mounted where the mails are kept, and locally" do
    production = ActiveSupport::EnvironmentInquirer.new("production")

    assert mailer_with({}).mail_viewer_mounted?(ActiveSupport::EnvironmentInquirer.new("development"))
    assert mailer_with({[:mail, :delivery_method] => "letter_opener_web"}).mail_viewer_mounted?(production)
    assert_not mailer_with({[:mail, :delivery_method] => "sendmail"}).mail_viewer_mounted?(production)
  end

  # On a server tmp/letter_opener is a link to a directory that survives
  # deploys. The viewer's "Clear" removes the mails' directory with rm_rf,
  # which would remove only the link and leave the mails; so they lie one level
  # deeper, where both the viewer and the delivery look for them.
  test "the kept mails lie in a directory of their own inside the linked one" do
    location = Rails.root.join("tmp/letter_opener/letters").to_s

    assert_equal location, LetterOpenerWeb.config.letters_location.to_s
    assert_equal location, ActionMailer::Base.letter_opener_web_settings[:location].to_s
  end

end
