module Admin
  module Mailers
    class EventsMailer < ApplicationMailer

      def reminder_message(registration, skip_if_sent: true)
        @registration = registration
        return if @registration.anonymized?
        return if skip_if_sent && @registration.reminder_message_sent_at.present?

        @event = @registration.event
        @offer = @event.offer

        mail(
          reply_to: @event.email_from || "schulung@ub.uni-paderborn.de",
          to: @registration.email,
          subject: "[UB Paderborn] Informationen zu Ihrer Schulungsveranstaltung"
        )
      end

      # Built from the still unsaved changes on the event, and only worth a mail
      # for the two attributes the template actually reports.
      def changed_notification(event, registration)
        @registration = registration

        @event = event
        @offer = @event.offer
        return unless @event.reportable_changes?

        mail(
          reply_to: @event.email_from || "schulung@ub.uni-paderborn.de",
          to: @registration.email,
          subject: "[UB Paderborn] Änderung eines Schulungstermins"
        )
      end

    end
  end
end
