module Admin
  class EventsController < ApplicationController

    include Filterable
    include EventFilter
    include EventBulkActions

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
