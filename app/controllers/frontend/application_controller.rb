module Frontend
  class ApplicationController < ::ApplicationController

    layout "frontend"

    private

    def prepare_offer_context
      add_breadcrumb "Angebote", frontend_offers_path

      offer_id = params[:offer_id] || params[:id] || return
      @offer = Offer.published                  # only published offers
                    .not_archived               # ... that are not archived
                    .includes(:upcoming_events) # eager load the associated upcoming events to avoid N+
                    .find(offer_id)             # find the offer by its ID

      if @offer.course?
        add_breadcrumb "Schulungen", frontend_offers_path(filter: {scope: "courses"})
      elsif @offer.consulting?
        add_breadcrumb "Beratungen", frontend_offers_path(filter: {scope: "consultings"})
      end

      add_breadcrumb @offer.title, frontend_offer_path(@offer)
    end

    def prepare_event_context
      add_breadcrumb "Angebote", frontend_offers_path
      add_breadcrumb "Schulungen", frontend_offers_path(filter: {scope: "courses"})
      add_breadcrumb "Termine", frontend_events_path

      event_id = params[:event_id] || params[:id] || return
      @event = Event.published                 # only published events
                    .upcoming                  # ... that are upcoming
                    .from_published_offers     # only from published offers
                    .from_non_archived_offers  # only from non-archived offers
                    .includes(:offer)          # eager load the associated offer to avoid N+1 queries
                    .find(event_id)            # find the event by its ID
      @offer = @event.offer

      add_breadcrumb @offer.title, frontend_offer_path(@offer)
      add_breadcrumb I18n.l(@event.date_and_time), frontend_offer_event_path(@offer, @event)
    end

  end
end
