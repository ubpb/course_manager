require "test_helper"

# The sitemap lists the fixed pages and every visible offer, so search engines
# find all of them and can tell which changed since their last visit.
module Frontend
  class SitemapTest < ActionDispatch::IntegrationTest

    include MailerRecords

    def entries
      Nokogiri::XML(response.body).remove_namespaces!.xpath("//url").to_h do |url|
        [url.at_xpath("loc").text, url.at_xpath("lastmod")&.text]
      end
    end

    test "the sitemap lists the fixed pages and the visible offers" do
      shown = create_offer(title: "Literaturrecherche")
      create_offer(title: "Entwurf", published: false)
      create_offer(title: "Alt", archived: true)

      get frontend_sitemap_path

      assert_response :success
      assert_equal "application/xml", response.media_type
      assert_equal [root_url, frontend_offers_url, frontend_contact_url, frontend_offer_url(shown)], entries.keys
      assert_includes response.headers["Cache-Control"], "public"
      assert_includes response.headers["Cache-Control"], "max-age=3600"
    end

    test "an offer changes with its latest event" do
      travel_to Time.zone.parse("2026-10-01 12:00") do
        @offer = create_offer
        @event = create_event
      end
      quiet = travel_to(Time.zone.parse("2026-10-02 12:00")) { create_offer(title: "Ohne Termine") }
      travel_to(Time.zone.parse("2026-10-20 08:30")) { @event.update!(location: "Raum 2.1") }

      get frontend_sitemap_path

      assert_equal "2026-10-20T08:30:00+02:00", entries[frontend_offer_url(@offer)]
      assert_equal "2026-10-02T12:00:00+02:00", entries[frontend_offer_url(quiet)]
      assert_nil entries[root_url]
    end

  end
end
