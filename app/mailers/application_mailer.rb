class ApplicationMailer < ActionMailer::Base

  default from: "schulung@ub.uni-paderborn.de"
  default reply_to: "schulung@ub.uni-paderborn.de"

  layout "mailer"

  # helper MailerHelper

end
