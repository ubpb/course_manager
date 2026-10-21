module Account
  class RegistrationsController < ApplicationController

    def index
      registrations = Registration.for_ils_user(current_user.ils_primary_id)
                                  .joins(:event).includes(event: [:offer, :certification])

      @upcoming_registrations = registrations.merge(Event.upcoming).order("events.date_and_time ASC")
      @past_registrations = registrations.merge(Event.past).order("events.date_and_time DESC")
    end

    # Die Mails verlinken hierher. Die Anmeldung wird daher auch dann gezeigt,
    # wenn Angebot oder Termin inzwischen unveröffentlicht oder archiviert sind.
    # Ist sie selbst storniert, gelöscht oder (10 Tage nach dem Termin)
    # anonymisiert, geht es statt auf eine 404-Seite zurück zur Übersicht.
    # Fremde Anmeldungen bekommen dieselbe Antwort, verraten also nicht, ob es
    # die id gibt.
    def show
      @registration = find_registration
      @event = @registration.event
      @offer = @event.offer

      add_breadcrumb @offer.title

      # The overview opens the page as a modal via ?modal=1. Asked for as a turbo
      # stream alone is not enough: Turbo keeps that through a whole redirect
      # chain, e.g. after a login, when the placeholder is gone.
      if params[:modal].present? && request.format.turbo_stream?
        render turbo_stream: turbo_stream.replace("registration-modal", partial: "modal",
                                                                        locals: {registration: @registration})
      else
        render :show, formats: [:html]
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to account_root_path, alert: t(".not_found")
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

    # After the login the overview -- and with it the #registration-modal
    # placeholder -- is gone, so come back as a full page by dropping ?modal.
    def return_to_path
      action_name == "show" ? account_registration_path(params[:id]) : super
    end

    # Nur die eigenen Anmeldungen sind auffindbar, damit die id aus der URL nicht
    # zum Zugriff auf fremde Anmeldungen (und deren Bescheinigungen) taugt.
    def find_registration
      Registration.for_ils_user(current_user.ils_primary_id)
                  .includes(event: [:offer, :certification])
                  .find(params[:id])
    end

  end
end
