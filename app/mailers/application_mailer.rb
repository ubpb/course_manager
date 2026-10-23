class ApplicationMailer < ActionMailer::Base

  # Mail templates (and the mail layout) live together under
  # app/views/mailers/<mailer_name>/ instead of directly in app/views. The
  # conventional location keeps working, as app/views stays a view path.
  prepend_view_path Rails.root.join("app/views/mailers")

  default from: "schulung@ub.uni-paderborn.de"
  default reply_to: "schulung@ub.uni-paderborn.de"

  layout "mailer"

  helper MailerHelper

  # A server may override, in its config/application.yml, how mails go out and
  # which host their links point to -- a test system delivers to
  # letter_opener_web and links to itself:
  #
  #   mail:
  #     delivery_method: letter_opener_web
  #     host: stage.ub.uni-paderborn.de
  #
  # Without these settings the defaults of the environment stay (production:
  # sendmail and schulungen.ub.uni-paderborn.de, see config/environments).
  def self.apply_server_settings(config = ApplicationConfig)
    delivery_method = config[:mail, :delivery_method]
    self.delivery_method = delivery_method.to_sym if delivery_method.present?

    host = config[:mail, :host]
    self.default_url_options = default_url_options.merge(host: host) if host.present?
  end

  apply_server_settings

end
