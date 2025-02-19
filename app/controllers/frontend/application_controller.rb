module Frontend
  class ApplicationController < ::ApplicationController

    private

    def prepare_event_context
      add_breadcrumb "Termine", frontend_events_path

      event_id = params[:id] || params[:event_id] || return
      @event = Event.published.includes(:course).find(event_id)

      add_breadcrumb I18n.l(@event.date_and_time), frontend_event_path(@event)
    end

  end
end
