class ApplicationMailer < ActionMailer::Base

  # Mail templates (and the mail layout) live together under
  # app/views/mailers/<mailer_name>/ instead of directly in app/views. The
  # conventional location keeps working, as app/views stays a view path.
  prepend_view_path Rails.root.join("app/views/mailers")

  default from: "schulung@ub.uni-paderborn.de"
  default reply_to: "schulung@ub.uni-paderborn.de"

  layout "mailer"

  helper MailerHelper

  # A server keeps the mails for reading (letter_opener_web, at /admin/mail), as
  # production.rb sets it, unless its config/application.yml lets them go out;
  # it may also set the host their links point to:
  #
  #   mail:
  #     delivery_method: sendmail          # on a production machine
  #     host: stage.ub.uni-paderborn.de    # on a test system
  #
  # Without these settings the defaults of the environment stay (production:
  # letter_opener_web and schulungen.ub.uni-paderborn.de, see
  # config/environments). A value no delivery method is registered for stops
  # the boot, not the first mail.
  def self.apply_server_settings(config = ApplicationConfig)
    delivery_method = config[:mail, :delivery_method]
    if delivery_method.present?
      unless ActionMailer::Base.delivery_methods.key?(delivery_method.to_sym)
        raise ArgumentError, "mail.delivery_method in config/application.yml: unknown #{delivery_method.to_s.inspect}"
      end

      self.delivery_method = delivery_method.to_sym
    end

    host = config[:mail, :host]
    self.default_url_options = default_url_options.merge(host: host) if host.present?
  end

  # Whether this system keeps its mails for reading instead of sending them;
  # then the admin's bar links them.
  def self.keeps_mails?
    delivery_method == :letter_opener_web
  end

  # Whether config/routes.rb mounts the viewer: where the mails are kept, and
  # locally, where the tests reach it too.
  def self.mail_viewer_mounted?(env = Rails.env)
    env.local? || keeps_mails?
  end

  apply_server_settings

end
