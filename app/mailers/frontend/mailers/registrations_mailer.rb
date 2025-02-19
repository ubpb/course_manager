module Frontend
  module Mailers
    class RegistrationsMailer < ApplicationMailer

      def confirmation(registration)
        prepare_context(registration)

        mail(
          reply_to: @event.effective_email_from || "schulung@ub.uni-paderborn.de",
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

      private

      def prepare_context(registration)
        @registration = registration
        @event = registration.event
        @course = registration.event.course
      end

    end
  end
end
