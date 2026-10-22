module Admin
  class EventsController < ApplicationController

    include Filterable
    include EventFilter

    before_action -> { add_breadcrumb "Termine", admin_events_path }
    before_action -> { persist_filter_params(:events) }, only: [:index, :reports]

    def index
      load_events
      setup_bulk_process_actions(@events)
    end

    # A new event needs its course first; the event form itself belongs to the
    # course (see Admin::Offers::EventsController#new).
    def new
      add_breadcrumb "Neuer Termin"
      @offers = Offer.courses.not_archived.order(:title)

      offer_id = params[:offer_id].presence || return
      offer = @offers.find_by(id: offer_id)

      if offer
        redirect_to new_admin_offer_event_path(offer)
      else
        flash.now[:alert] = "Bitte ein Angebot auswählen"
        render :new, status: :unprocessable_content
      end
    end

    def bulk_process
      events = Event.where(id: params[:bulk_process_ids])

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

      redirect_to admin_events_path
    end

    def bulk_move
      events = Event.where(id: params[:event_ids])
      offer = Offer.courses.find_by(id: params[:target_offer_id])

      if offer.nil? || events.none?
        flash[:alert] = "Bitte Termine und Ziel-Angebot auswählen"
      else
        events.update_all(offer_id: offer.id) # rubocop:disable Rails/SkipsModelValidations -- see bulk_process
        flash[:success] = "Termin(e) wurde(n) nach \"#{offer.title}\" verschoben"
      end

      redirect_to admin_events_path
    end

    def reports
      prepare_report_export(load_events)

      respond_to do |format|
        format.xlsx do
          response.headers["Content-Disposition"] = "attachment; filename=\"#{report_export_filename}.xlsx\""

          render "admin/offers/events/reports/show"
        end
      end
    end

    private

    # The dialog for picking the target offer, opened as a modal.
    def render_move_to_offer_form(events)
      render turbo_stream: turbo_stream.replace(
        "bulk-action-form",
        partial: "bulk_action_move_to_offer",
        locals: {
          events: events.includes(:offer),
          offers: Offer.courses.order(:title),
          url: bulk_move_admin_events_path,
          container_id: "bulk-action-form"
        }
      )
    end

    def setup_bulk_process_actions(events)
      @bulk_process_actions = []
      return if events.empty?

      @bulk_process_actions << ["Veröffentlichen", "publish"]
      @bulk_process_actions << ["Veröffentlichung zurückziehen", "unpublish"]
      @bulk_process_actions << ["In anderes Angebot verschieben", "move_to_offer"]
    end

    def load_events
      @events = filtered_events(Event.includes(:offer, :report, :certification).order(date_and_time: :desc))
    end

  end
end
