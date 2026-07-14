module Frontend
  module Events
    class RegistrationsController < ApplicationController

      before_action :authenticate_user!
      before_action :prepare_event_context
      before_action -> { add_breadcrumb "Anmeldung", frontend_event_registrations_path(@event) }

      def index
        redirect_to new_frontend_event_registration_path(@event)
      end

      def new
        @registration = @event.registrations.build(
          first_name: current_user.first_name,
          last_name: current_user.last_name,
          email: current_user.email
        )
        ensure_registration_is_possible
      end

      def create
        @registration = @event.registrations.build(registration_params)
        # Never taken from the params, so a user cannot register on behalf of someone else
        @registration.ils_primary_id = current_user.ils_primary_id
        ensure_registration_is_possible or return

        if @registration.save(context: :user_registration)
          # Send confirmation to user
          Frontend::Mailers::RegistrationsMailer.confirmation(@registration).deliver_later
          # Send notification to Schulungs-Team
          Frontend::Mailers::RegistrationsMailer.notification(@registration).deliver_later

          redirect_to frontend_offer_path(@event.offer), notice: "Anmeldung erfolgreich. Wir haben Ihnen eine Bestätigung per E-Mail gesendet."
        else
          render :new, status: :unprocessable_entity
        end
      end

      private

      def registration_params
        params.require(:registration).permit(:first_name, :last_name, :email, :user_notes, :gdrp_consent)
      end

      def ensure_registration_is_possible
        # Abort if registration is not needed
        unless @event.registration_required?
          redirect_to frontend_offer_path(@event.offer), alert: "Anmeldung nicht erforderlich"
          return false
        end

        # Abort if registration is closed
        if @event.registration_closed?
          redirect_to frontend_offer_path(@event.offer), alert: "Die Anmeldung ist geschlossen"
          return false
        end

        # Abort if the user is already registered for this event
        if @event.registrations.exists?(ils_primary_id: current_user.ils_primary_id)
          redirect_to frontend_offer_path(@event.offer), alert: "Sie sind bereits für diesen Termin angemeldet."
          return false
        end

        # Registration is possible
        true
      end

    end
  end
end
