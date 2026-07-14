module Frontend
  module Mailers
    class RegistrationsMailer < ApplicationMailer

      def confirmation(registration)
        prepare_context(registration)

        mail(
          reply_to: @event.email_from || "schulung@ub.uni-paderborn.de",
          to: @registration.email,
          subject: "[UB Paderborn] Ihre Schulungsanmeldung"
        )
      end

      def notification(registration)
        prepare_context(registration)

        mail(
          to: "schulung@ub.uni-paderborn.de",
          subject: "[SchulungsDB] Eine neue Anmeldung"
        )
      end

      # The registration is already destroyed when a cancellation mail is sent,
      # so these take the event and plain registrant data instead of the record.
      def cancellation_confirmation(event, full_name:, email:)
        prepare_cancellation_context(event, full_name, email)

        mail(
          reply_to: @event.email_from || "schulung@ub.uni-paderborn.de",
          to: email,
          subject: "[UB Paderborn] Ihre Abmeldung von einer Schulung"
        )
      end

      def cancellation_notification(event, full_name:, email:)
        prepare_cancellation_context(event, full_name, email)

        mail(
          to: "schulung@ub.uni-paderborn.de",
          subject: "[SchulungsDB] Eine Anmeldung wurde storniert"
        )
      end

      private

      def prepare_context(registration)
        @registration = registration
        @event = registration.event
        @offer = registration.event.offer
      end

      def prepare_cancellation_context(event, full_name, email)
        @event = event
        @offer = event.offer
        @full_name = full_name
        @email = email
      end

    end
  end
end
