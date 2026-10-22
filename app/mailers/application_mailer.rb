class ApplicationMailer < ActionMailer::Base

  default from: "schulung@ub.uni-paderborn.de"
  default reply_to: "schulung@ub.uni-paderborn.de"

  layout "mailer"

  helper MailerHelper

  private

  # Mails to participants name their kind first and then the offer and the date
  # of the event, so the inbox shows at a glance which course and which date a
  # mail is about. For a change notice that is the new date.
  def participant_subject(kind)
    "[UB Paderborn] #{kind}: #{@offer.title} (#{I18n.l(@event.date_and_time.to_date)})"
  end

end
