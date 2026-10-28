module Admin
  class EventsController < ApplicationController

    include Filterable
    include EventFilter
    include EventBulkActions
    include ModalForm

    OFFER_MISSING = "Bitte ein Angebot auswählen".freeze

    before_action -> { add_breadcrumb "Termine", admin_events_path }
    before_action -> { persist_filter_params(:events) }, only: [:index, :reports]

    def index
      load_events
      setup_bulk_process_actions(@events)
    end

    # A new event needs its course first; the event form itself belongs to the
    # course (see Admin::Offers::EventsController#new). In the modal, the
    # choice of the course turns into the event form; as pages, the choice
    # leads to the form's page.
    def new
      add_breadcrumb "Neuer Termin"
      @offers = Offer.courses.not_archived.order(:title)

      offer_id = params[:offer_id].presence
      return respond_with_modal(offers: @offers) unless offer_id

      offer = @offers.find_by(id: offer_id)

      if offer
        respond_with_event_form(offer)
      else
        # The page shows the flash, the modal its own alert.
        flash.now[:alert] = OFFER_MISSING
        respond_with_errors(:new, offers: @offers, error: OFFER_MISSING)
      end
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

    # Replaces only the content of the open modal, like errors do.
    def respond_with_event_form(offer)
      respond_to do |format|
        format.html { redirect_to new_admin_offer_event_path(offer) }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "event-form", partial: "admin/offers/events/form", locals: {offer: offer, event: offer.events.build}
          )
        end
      end
    end

    # See EventBulkActions.
    def bulk_events
      Event.all
    end

    def bulk_target_offers
      Offer.courses
    end

    def bulk_return_path
      admin_events_path
    end

    def load_events
      @events = filtered_events(Event.includes(:offer, :report, :certification).order(date_and_time: :desc))
    end

  end
end
