class ApplicationMailer < ActionMailer::Base

  default from: "schulung@ub.uni-paderborn.de"
  default reply_to: "schulung@ub.uni-paderborn.de"

  layout "mailer"

  helper MailerHelper

  private

  # Mails to participants name their kind first and then the offer, so the
  # inbox shows at a glance which course a mail is about.
  def participant_subject(kind)
    "[UB Paderborn] #{kind}: #{@offer.title}"
  end

end
