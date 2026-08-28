module Frontend
  class SitemapsController < ApplicationController

    # XML for search engines only -- no layout, no breadcrumb, no filters.
    layout false

    def show
      offers = Offer.published.not_archived.order(:id).to_a

      # An offer page also renders its events, so a changed event makes the
      # offer page stale. Collected in one query to avoid an N+1.
      last_event_change = Event.where(offer: offers).group(:offer_id).maximum(:updated_at)

      @urls = static_urls + offers.map do |offer|
        {
          loc: frontend_offer_url(offer),
          lastmod: [offer.updated_at, last_event_change[offer.id]].compact.max,
          changefreq: "weekly",
          priority: "0.8"
        }
      end

      expires_in 1.hour, public: true
    end

    private

    def static_urls
      [
        {loc: root_url, changefreq: "monthly", priority: "1.0"},
        {loc: frontend_offers_url, changefreq: "daily", priority: "0.9"},
        {loc: frontend_contact_url, changefreq: "yearly", priority: "0.3"}
      ]
    end

  end
end
