require "test_helper"

# The public page of an offer lives at a URL with the title as slug and is only
# there for offers that are published and not archived.
module Frontend
  class OfferPageTest < ActionDispatch::IntegrationTest

    include MailerRecords

    def breadcrumb_labels
      css_select("ol.breadcrumb li").map { it.text.strip }.drop(2)
    end

    test "an offer is found by its id alone and led to its current slug" do
      offer = create_offer(title: "Literaturrecherche")

      get frontend_offer_path(id: offer.id)

      assert_response :moved_permanently
      assert_redirected_to "/angebote/#{offer.id}-literaturrecherche"
    end

    test "an outdated slug leads to the current one" do
      offer = create_offer(title: "Literaturrecherche")

      get "/angebote/#{offer.id}-alter-titel"

      assert_response :moved_permanently
      assert_redirected_to frontend_offer_path(offer)
    end

    test "unpublished and archived offers have no page" do
      [create_offer(published: false), create_offer(archived: true)].each do |offer|
        get frontend_offer_path(offer)

        assert_response :not_found
      end
    end

    test "the breadcrumb leads back to the list of the offer's kind" do
      {"course" => ["Angebote", "Schulungen", "Literaturrecherche"],
       "consulting" => ["Angebote", "Beratungen", "Literaturrecherche"],
       "self_study_course" => ["Angebote", "Literaturrecherche"]}.each do |type, labels|
        offer = create_offer(type: type)

        get frontend_offer_path(offer)

        assert_response :success
        assert_equal labels, breadcrumb_labels
      end
    end

    test "only published upcoming events are shown" do
      @offer = create_offer
      shown = create_event(date_and_time: 1.week.from_now, location: "Raum A")
      create_event(date_and_time: 2.weeks.from_now, location: "Raum B", published: false)
      create_event(date_and_time: 1.week.ago, location: "Raum C")

      get frontend_offer_path(@offer)

      assert_select "##{ActionView::RecordIdentifier.dom_id(shown)}"
      assert_includes response.body, "Raum A"
      assert_not_includes response.body, "Raum B"
      assert_not_includes response.body, "Raum C"
    end

  end
end
