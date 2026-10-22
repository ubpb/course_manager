class ApplicationMailer < ActionMailer::Base

  # Mail templates (and the mail layout) live together under
  # app/views/mailers/<mailer_name>/ instead of directly in app/views. The
  # conventional location keeps working, as app/views stays a view path.
  prepend_view_path Rails.root.join("app/views/mailers")

  default from: "schulung@ub.uni-paderborn.de"
  default reply_to: "schulung@ub.uni-paderborn.de"

  layout "mailer"

  helper MailerHelper

end
