module Admin
  module ContextHelpers

    extend ActiveSupport::Concern

    private

    def prepare_offer_context
      add_breadcrumb "Angebote", admin_offers_path

      offer_id = params[:offer_id] || params[:id] || return
      @offer = Offer.includes(:events).find(offer_id)

      add_breadcrumb @offer.title, edit_admin_offer_path(@offer)
    end

    def prepare_offer_event_context
      prepare_offer_context

      unless @offer.course?
        redirect_back(fallback_location: admin_offers_path, alert: "Nur Kurse können Termine haben.")
        return
      end

      add_breadcrumb "Termine", admin_offer_events_path(@offer)

      event_id = params[:event_id] || params[:id] || return
      @event = @offer.events.includes(:report, :registrations).find(event_id)

      add_breadcrumb I18n.l(@event.date_and_time), edit_admin_offer_event_path(@offer, @event)
    end

    def prepare_offer_event_registration_context
      prepare_offer_event_context

      add_breadcrumb "Anmeldungen", admin_offer_event_registrations_path(@offer, @event)

      registration_id = params[:registration_id] || params[:id] || return
      @registration = @event.registrations.find(registration_id)

      add_breadcrumb @registration.full_name_reversed, edit_admin_offer_event_path(@offer, @event)
    end

    def prepare_offer_event_report_context
      prepare_offer_event_context

      @report = @event.report
      add_breadcrumb "Statistik", admin_offer_event_report_path(@offer, @event)
    end

    def prepare_offer_event_certification_context
      prepare_offer_event_context

      @certification = @event.certification
      add_breadcrumb "Zertifizierung", admin_offer_event_certification_path(@offer, @event)
    end

  end
end
