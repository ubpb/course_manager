module Frontend
  class ApplicationController < ::ApplicationController

    layout "frontend"

    private

    def prepare_offers_context
      add_breadcrumb "Angebote", frontend_offers_path
    end

    def prepare_offer_context
      offer_id = params[:offer_id] || params[:id] || return
      @offer = Offer.published.find(offer_id)

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
      @event = Event.published.includes(:offer).find(event_id)

      add_breadcrumb @event.offer.title, frontend_offer_path(@event.offer)
      add_breadcrumb I18n.l(@event.date_and_time), frontend_event_path(@event)
    end

  end
end
