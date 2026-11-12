module Frontend
  module Events
    class RegistrationsController < ApplicationController

      ALREADY_REGISTERED = "Sie sind bereits für diesen Termin angemeldet.".freeze

      # No login needed: guests register as well. A logged-in user gets the form
      # prefilled and the registration linked to the account.
      before_action :prepare_event_context
      before_action -> { add_breadcrumb "Anmeldung", frontend_event_registrations_path(@event) }
      before_action :ensure_registration_is_possible, only: [:new, :create]

      def index
        redirect_to new_frontend_event_registration_path(@event)
      end

      def new
        @registration = @event.registrations.build(
          first_name: current_user&.first_name,
          last_name: current_user&.last_name,
          email: current_user&.email
        )

        # The modal is only ever requested by the "Jetzt anmelden" link on the
        # offer page, which says so via ?modal=1. The response format alone
        # cannot be used to decide this: Turbo keeps asking for a turbo stream
        # through a whole redirect chain, so the request that arrives after a
        # login from the form also looks like a stream request -- but by then
        # the page holding the #registration-modal placeholder is gone and the
        # stream would be dropped silently. Everything else renders the full
        # page.
        if modal_request?
          render turbo_stream: turbo_stream.replace(
            "registration-modal",
            partial: "modal",
            locals: {event: @event, registration: @registration}
          )
        else
          render :new, formats: [:html]
        end
      end

      def create
        @registration = @event.registrations.build(registration_params)
        # Never taken from the params, so a user cannot register on behalf of
        # someone else's account
        @registration.ils_primary_id = current_user&.ils_primary_id
        @registration.origin = current_user ? :account : :guest

        if @registration.save(context: :user_registration)
          # Send confirmation to user
          ParticipantMailer.confirmation(@registration).deliver_later
          # Send notification to Schulungs-Team
          TeamMailer.new_registration(@registration).deliver_later

          redirect_to frontend_offer_path(@event.offer),
                      notice: "Anmeldung erfolgreich. Wir haben Ihnen eine Bestätigung per E-Mail gesendet."
        else
          respond_to do |format|
            format.html { render :new, status: :unprocessable_content }
            format.turbo_stream do
              render turbo_stream: turbo_stream.replace(
                "registration-form",
                partial: "form",
                locals: {event: @event, registration: @registration, modal: modal_request?}
              ), status: :unprocessable_content
            end
          end
        end
      rescue ActiveRecord::RecordNotUnique
        # Another request registered the same account a moment earlier (a double
        # click, two tabs): the checks passed for both, the unique index on
        # (event_id, ils_primary_id) stopped this one. Guests carry no ILS id,
        # so only a logged-in user gets here.
        redirect_to frontend_offer_path(@event.offer), alert: ALREADY_REGISTERED
      end

      private

      def modal_request?
        params[:modal].present? && request.format.turbo_stream?
      end

      def registration_params
        params.expect(
          registration: [:first_name, :last_name, :email, :field_of_interest, :user_notes, :gdrp_consent]
        )
      end

      # As a before_action: the redirect stops the request when the user cannot
      # register for the event.
      def ensure_registration_is_possible
        alert =
          if !@event.registration_required?
            "Anmeldung nicht erforderlich"
          elsif @event.registration_closed?
            "Die Anmeldung ist geschlossen"
          elsif current_user && @event.registrations.exists?(ils_primary_id: current_user.ils_primary_id)
            ALREADY_REGISTERED
          end

        redirect_to frontend_offer_path(@event.offer), alert: alert if alert
      end

    end
  end
end
