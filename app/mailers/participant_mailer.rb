# Every mail that goes to a participant, whoever triggers it: the participant
# (confirmation, cancellation), staff in the admin (change notice, message,
# certificate, reminder) or the reminder cron task.
class ParticipantMailer < ApplicationMailer

  def confirmation(registration)
    prepare_context(registration)

    mail(
      reply_to: @event.email_from || "schulung@ub.uni-paderborn.de",
      to: @registration.email,
      subject: participant_subject("Anmeldebestätigung")
    )
  end

  # Die Registration ist zu diesem Zeitpunkt bereits gelöscht, daher werden
  # die benötigten Daten als einfache Werte übergeben (Active Job kann keine
  # Records ohne id serialisieren).
  def cancellation_confirmation(event, full_name:, email:)
    @event = event
    @offer = event.offer
    @full_name = full_name
    @email = email

    mail(
      reply_to: @event.email_from || "schulung@ub.uni-paderborn.de",
      to: @email,
      subject: participant_subject("Abmeldebestätigung")
    )
  end

  def reminder(registration, skip_if_sent: true)
    @registration = registration
    return if @registration.anonymized?
    return if skip_if_sent && @registration.reminder_message_sent_at.present?

    @event = @registration.event
    @offer = @event.offer

    mail(
      reply_to: @event.email_from || "schulung@ub.uni-paderborn.de",
      to: @registration.email,
      subject: participant_subject("Erinnerung")
    )
  end

  # Built from the still unsaved changes on the event, and only worth a mail
  # for the two attributes the template actually reports.
  def change_notice(event, registration)
    @registration = registration
    return if @registration.anonymized?

    @event = event
    @offer = @event.offer
    return unless @event.reportable_changes?

    mail(
      reply_to: @event.email_from || "schulung@ub.uni-paderborn.de",
      to: @registration.email,
      subject: participant_subject("Terminänderung")
    )
  end

  # Not named "message": ActionMailer uses that for the mail itself.
  def staff_message(registration, message)
    prepare_context(registration)
    @message = message

    mail(
      reply_to: @event.email_from || "schulung@ub.uni-paderborn.de",
      to: @registration.email,
      subject: "[UB Paderborn] #{@message.subject}"
    )
  end

  def certificate(registration, certificate, certificate_filename)
    @registration = registration
    return if @registration.anonymized?

    @event = @registration.event
    return if @event.certification.blank?

    @offer = @event.offer

    attachments[certificate_filename] = certificate
    mail(
      reply_to: @event.email_from || "schulung@ub.uni-paderborn.de",
      to: @registration.email,
      subject: participant_subject("Teilnahmebescheinigung")
    )
  end

  private

  def prepare_context(registration)
    @registration = registration
    @event = registration.event
    @offer = @event.offer
  end

  # The kind of mail first, then the offer and the date of the event, so the
  # inbox shows at a glance which course and which date a mail is about. For a
  # change notice that is the new date.
  def participant_subject(kind)
    "[UB Paderborn] #{kind}: #{@offer.title} (#{I18n.l(@event.date_and_time.to_date)})"
  end

end
