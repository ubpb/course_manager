module Account
  class RegistrationsController < ApplicationController

    def index
      registrations = Registration.for_ils_user(current_user.ils_primary_id)
                                  .joins(:event).includes(event: [:offer, :certification])

      @upcoming_registrations = registrations.merge(Event.upcoming).order("events.date_and_time ASC")
      @past_registrations = registrations.merge(Event.past).order("events.date_and_time DESC")
    end

    def certificate
      registration = find_registration

      if registration.certificate_available?
        send_data(
          Certificate.generate(registration),
          filename: Certificate.filename(registration),
          type: "application/pdf",
          disposition: "attachment"
        )
      else
        redirect_to account_root_path, alert: t("account.registrations.certificate.not_available"), status: :see_other
      end
    end

    def destroy
      @registration = find_registration
      @event = @registration.event

      if @event.upcoming?
        full_name = @registration.full_name
        email = @registration.email

        @registration.destroy

        # Die Registration ist zu diesem Zeitpunkt bereits gelöscht, daher werden
        # die benötigten Daten als einfache Werte übergeben (Active Job kann keine
        # Records ohne id serialisieren).
        Frontend::Mailers::RegistrationsMailer
          .cancellation_confirmation(@event, full_name: full_name, email: email)
          .deliver_later
        Frontend::Mailers::RegistrationsMailer
          .cancellation_notification(@event, full_name: full_name, email: email)
          .deliver_later

        redirect_to account_root_path, notice: t("account.registrations.destroy.success"), status: :see_other
      else
        redirect_to account_root_path, alert: t("account.registrations.destroy.not_allowed"), status: :see_other
      end
    end

    private

    # Nur die eigenen Anmeldungen sind auffindbar, damit die id aus der URL nicht
    # zum Zugriff auf fremde Anmeldungen (und deren Bescheinigungen) taugt.
    def find_registration
      Registration.for_ils_user(current_user.ils_primary_id)
                  .includes(event: [:offer, :certification])
                  .find(params[:id])
    end

  end
end
