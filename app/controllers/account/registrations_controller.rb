module Account
  class RegistrationsController < ApplicationController

    def index
      registrations = Registration.for_ils_user(current_user.ils_primary_id)
                                  .joins(:event).includes(event: :offer)

      @upcoming_registrations = registrations.merge(Event.upcoming).order("events.date_and_time ASC")
      @past_registrations = registrations.merge(Event.past).order("events.date_and_time DESC")
    end

    def destroy
      @registration = Registration.for_ils_user(current_user.ils_primary_id).find(params[:id])
      @event = @registration.event

      if @event.upcoming?
        @registration.destroy

        # The registration is destroyed, so pass the event and plain
        # registrant data to the mailers instead of the record.
        Frontend::Mailers::RegistrationsMailer
          .cancellation_confirmation(@event, full_name: @registration.full_name, email: @registration.email)
          .deliver_later
        Frontend::Mailers::RegistrationsMailer
          .cancellation_notification(@event, full_name: @registration.full_name, email: @registration.email)
          .deliver_later

        redirect_to account_root_path, notice: t("account.registrations.destroy.success"), status: :see_other
      else
        redirect_to account_root_path, alert: t("account.registrations.destroy.not_allowed"), status: :see_other
      end
    end

  end
end
