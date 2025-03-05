module Mailers
  class EventsMailer < ApplicationMailer

    def reminder_message(registration, skip_if_sent: true)
      @registration = registration
      return if @registration.anonymized?
      return if skip_if_sent && @registration.reminder_message_sent_at.present?

      @event = @registration.event
      @course = @event.course

      @reminder_message = @event.effective_reminder_message
      return if @reminder_message.blank?

      mail(
        reply_to: @event.effective_email_from || "schulung@ub.uni-paderborn.de",
        to: @registration.email,
        subject: "[UB Paderborn] Informationen zu Ihrer Schulungsveranstaltung"
      )
    end

    def changed_notification(event, registration)
      @registration = registration

      @event = event
      @course = @event.course
      return unless @event.changes.any?

      mail(
        reply_to: @event.effective_email_from || "schulung@ub.uni-paderborn.de",
        to: @registration.email,
        subject: "[UB Paderborn] Änderung eines Schulungstermins"
      )
    end

  end
end
