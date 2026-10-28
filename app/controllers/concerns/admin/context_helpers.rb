module Admin
  module ContextHelpers

    extend ActiveSupport::Concern

    included do
      helper_method :event_list_path, :offer_page_path, :offer_page?
    end

    private

    # The list an event leads back to: the events of its offer in the offer
    # context, the global event list otherwise.
    def event_list_path(event = @event)
      anchor = ActionView::RecordIdentifier.dom_id(event) if event&.persisted?

      if offer_context?
        admin_offer_events_path(@offer, anchor: anchor, nav_scope: nil)
      else
        admin_events_path(anchor: anchor, nav_scope: nil)
      end
    end

    # Courses open on their events, all other offers on their data.
    def offer_page_path(offer)
      if offer.course?
        admin_offer_events_path(offer, nav_scope: nil)
      else
        edit_admin_offer_path(offer, nav_scope: nil)
      end
    end

    # Whether the current page is a tab of the offer page.
    def offer_page?
      @offer_page == true
    end

    def prepare_offer_context
      add_breadcrumb "Angebote", admin_offers_path(nav_scope: nil)

      offer_id = params[:id] || return
      @offer = Offer.includes(:events).find(offer_id)

      add_breadcrumb @offer.title, offer_page_path(@offer)
    end

    # `offer_page: true` for the event list of the offer page, which belongs to
    # the offer context without a nav_scope.
    def prepare_offer_event_context(offer_page: false)
      @offer = Offer.includes(:events).find(params[:offer_id])

      unless @offer.course?
        redirect_back_or_to(admin_offers_path, alert: "Nur Kurse können Termine haben.")
        return
      end

      @offer_page = offer_page

      event_id = params[:event_id] || params[:id]
      @event = @offer.events.includes(:report, :registrations).find(event_id) if event_id

      if offer_page
        add_offer_breadcrumbs
        add_breadcrumb "Termine"
      elsif offer_context?
        add_offer_breadcrumbs
        add_breadcrumb event_breadcrumb_date, admin_offer_event_registrations_path(@offer, @event) if @event
      else
        add_breadcrumb "Termine", admin_events_path(nav_scope: nil)
        if @event
          add_breadcrumb "#{event_breadcrumb_date} · #{@offer.title}",
                         admin_offer_event_registrations_path(@offer, @event)
        end
      end
    end

    def prepare_offer_event_registration_context
      prepare_offer_event_context
      return if performed?

      add_breadcrumb "Teilnehmer", admin_offer_event_registrations_path(@offer, @event)

      registration_id = params[:registration_id] || params[:id] || return
      @registration = @event.registrations.find(registration_id)

      add_breadcrumb @registration.full_name_reversed,
                     edit_admin_offer_event_registration_path(@offer, @event, @registration)
    end

    def prepare_offer_event_report_context
      prepare_offer_event_context
      return if performed?

      @report = @event.report
      add_breadcrumb "Statistik", admin_offer_event_report_path(@offer, @event)
    end

    def prepare_offer_event_certification_context
      prepare_offer_event_context
      return if performed?

      @certification = @event.certification
      add_breadcrumb "Zertifikat", admin_offer_event_certification_path(@offer, @event)
    end

    def add_offer_breadcrumbs
      add_breadcrumb "Angebote", admin_offers_path(nav_scope: nil)
      add_breadcrumb @offer.title, offer_page_path(@offer)
    end

    def event_breadcrumb_date
      I18n.l(@event.date_and_time, format: "%d.%m.%Y, %H:%M")
    end

  end
end
