require "test_helper"

# A page whose record is gone -- deleted in another tab or by a colleague, and
# still linked from the menu bar there -- leads to the list of its area with
# a note instead of an error page.
module Admin
  class MissingRecordsTest < ActionDispatch::IntegrationTest

    include AdminLogin
    include MailerRecords

    MISSING = "Den aufgerufenen Eintrag gibt es nicht (mehr).".freeze

    setup do
      @offer = create_offer
      @event = create_event

      log_in_admin
    end

    test "a deleted offer leads to the offer list" do
      paths = [edit_admin_offer_path(@offer), admin_offer_events_path(@offer)]
      @offer.destroy!

      paths.each do |path|
        get path

        assert_redirected_to admin_offers_path, "for #{path}"
      end

      follow_redirect!

      assert_select "#admin-toasts .toast[role=alert]", text: MISSING
    end

    test "a deleted event leads to the list it was opened from" do
      in_offer = admin_offer_event_registrations_path(@offer, @event, nav_scope: "offer")
      global = admin_offer_event_registrations_path(@offer, @event)
      @event.destroy!

      get in_offer

      assert_redirected_to admin_offers_path

      get global

      assert_redirected_to admin_events_path
    end

    test "a deleted topic leads to the topic list" do
      topic = Topic.create!(title: "Recherche")
      path = edit_admin_topic_path(topic)
      topic.destroy!

      get path

      assert_redirected_to admin_topics_path
    end

    # Turbo follows a 303 with a GET, the other redirects with the method of
    # the form.
    test "a form sent for a deleted record is redirected with a GET" do
      path = admin_offer_path(@offer)
      @offer.destroy!

      patch path, params: {offer: {title: "Datenmanagement"}}

      assert_response :see_other
      assert_redirected_to admin_offers_path
    end

  end
end
