module Admin
  module Offers
    class EventsController < ApplicationController

      include Filterable
      include EventFilter

      before_action -> { prepare_offer_event_context(offer_page: true) }, only: [:index, :bulk_process, :bulk_move]
      before_action -> { persist_filter_params(:events) }, only: :index
      before_action :prepare_offer_event_context, except: [:index, :bulk_process, :bulk_move]
      before_action -> { add_breadcrumb "Termindaten" }, only: [:edit, :update]
      before_action -> { add_breadcrumb "Neuer Termin" }, only: [:new, :create]

      def index
        @events = filtered_events(@offer.events.includes(:offer, :report, :certification).order(date_and_time: :desc))

        setup_bulk_process_actions(@events)
      end

      def bulk_process
        events = @offer.events.where(id: params[:bulk_process_ids])

        # Every branch ends in the redirect below, so the flash messages must not be
        # flash.now (the cop misreads the case branches). update_all on purpose: one
        # old, invalid record must not stop a bulk change.
        # rubocop:disable-next Rails/ActionControllerFlashBeforeRender, Rails/SkipsModelValidations
        case params[:bulk_process_action]
        when "publish"
          events.update_all(published: true)
          flash[:success] = "Termin(e) wurde(n) veröffentlicht"
        when "unpublish"
          events.update_all(published: false)
          flash[:success] = "Veröffentlichung von Termin(en) wurde zurückgezogen"
        when "move_to_offer"
          return render_move_to_offer_form(events) if events.any?

          flash[:alert] = "Bitte mindestens einen Termin auswählen"
        end

        redirect_to admin_offer_events_path(@offer)
      end

      def bulk_move
        events = @offer.events.where(id: params[:event_ids])
        offer = Offer.courses.where.not(id: @offer.id).find_by(id: params[:target_offer_id])

        if offer.nil? || events.none?
          flash[:alert] = "Bitte Termine und Ziel-Angebot auswählen"
        else
          events.update_all(offer_id: offer.id) # rubocop:disable Rails/SkipsModelValidations -- see bulk_process
          flash[:success] = "Termin(e) wurde(n) nach \"#{offer.title}\" verschoben"
        end

        redirect_to admin_offer_events_path(@offer)
      end

      def new
        @event = @offer.events.build
      end

      def edit; end

      def create
        @event = @offer.events.build(event_params)

        if @event.save
          redirect_to edit_admin_offer_event_path(@offer, @event), notice: t("admin.application.form.success")
        else
          render :new, status: :unprocessable_content
        end
      end

      def update
        @event.assign_attributes(event_params)

        if @event.valid?
          if @event.upcoming? && @event.reportable_changes?
            @event.registrations.each do |registration|
              # Must be send with #deliver and not #deliver_later, because the event is saved afterwards
              # ans we need the changes to be present in the email
              ParticipantMailer.change_notice(@event, registration).deliver
            end
          end

          @event.save

          redirect_to edit_admin_offer_event_path(@offer, @event), notice: t("admin.application.form.success")
        else
          render :edit, status: :unprocessable_content
        end
      end

      def destroy
        @event.destroy

        flash[:notice] = t("admin.application.form.destroy_success")
        redirect_to event_list_path
      end

      def duplicate
        new_date_and_time = Time.zone.now
        new_date_and_time = new_date_and_time.change(sec: 0, usec: 0)

        event = @offer.events.find(params.expect(:id)).dup
        event.registrations_count = 0
        event.published = false
        event.date_and_time = new_date_and_time
        event.save

        flash[:notice] =
          "Der Termin wurde dupliziert und gespeichert. Datum und Uhrzeit wurden auf die aktuelle Zeit eingestellt. " \
          "Bitte bearbeite die Details."
        redirect_to edit_admin_offer_event_path(@offer, event)
      end

      # The previews show the mails as they would go out with what the form
      # currently holds -- of a new event as well as of an existing one. Nothing
      # is saved, so no change notice is sent either.
      def preview_confirmation
        render_mail_preview("Vorschau: E-Mail Anmeldebestätigung") do |registration|
          ParticipantMailer.confirmation(registration)
        end
      end

      def preview_reminder
        render_mail_preview("Vorschau: Erinnerungsmail") do |registration|
          ParticipantMailer.reminder(registration, skip_if_sent: false)
        end
      end

      private

      # The dialog for picking the target offer, opened as a modal in the list
      # (upcoming or past) it was started from.
      def render_move_to_offer_form(events)
        render turbo_stream: turbo_stream.replace(
          "bulk-action-form",
          partial: "admin/events/bulk_action_move_to_offer",
          locals: {
            events: events.includes(:offer),
            offers: Offer.courses.where.not(id: @offer.id).order(:title),
            url: bulk_move_admin_offer_events_path(@offer),
            container_id: "bulk-action-form"
          }
        )
      end

      # The mail texts need a date, so without one there is only a hint.
      def render_mail_preview(title)
        event = @offer.events.build(event_params)
        mail = yield(preview_registration(event)) if event.date_and_time.present?

        render turbo_stream: turbo_stream.replace(
          "mail-preview-modal",
          partial: "mail_preview_modal",
          locals: {title: title, mail: mail}
        )
      end

      # The mails most participants get: those for a registration made from an
      # account. Its link to the detail page needs an id.
      def preview_registration(event)
        Registration.new(
          id: 0,
          ils_primary_id: "preview",
          event: event,
          first_name: "Max",
          last_name: "Mustermann",
          email: "schulung@ub.uni-paderborn.de"
        )
      end

      def setup_bulk_process_actions(events)
        @bulk_process_actions = []
        return if events.empty?

        @bulk_process_actions << ["Veröffentlichen", "publish"]
        @bulk_process_actions << ["Veröffentlichung zurückziehen", "unpublish"]
        @bulk_process_actions << ["In anderes Angebot verschieben", "move_to_offer"]
      end

      def event_params
        params.expect(
          event: [
            :date_and_time, :duration, :location, :participant_notes,
            :email_from, :online, :online_url, :published, :registration_required,
            :max_no_of_participants
          ]
        )
      end

    end
  end
end
