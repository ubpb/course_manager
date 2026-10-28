require "test_helper"

# A new event can be started from the global event list: staff choose the
# course first and then fill in the usual event form.
module Admin
  class NewEventTest < ActionDispatch::IntegrationTest

    include AdminLogin
    include MailerRecords

    setup do
      @offer = create_offer
      @archived = create_offer(title: "Alt", archived: true)
      @consulting = create_offer(title: "Beratung Publizieren", type: "consulting")

      log_in_admin
    end

    test "the global list starts a new event" do
      get admin_events_path

      assert_select "a[href=?]", new_admin_event_path, text: /Neuer Termin/
    end

    test "only current courses can be chosen" do
      get new_admin_event_path

      assert_response :success
      assert_select "select[name=offer_id] option", count: 1, text: "Literaturrecherche"
    end

    test "choosing a course opens its event form outside the offer context" do
      get new_admin_event_path(offer_id: @offer.id)

      assert_redirected_to new_admin_offer_event_path(@offer)
    end

    test "an unsuitable offer is refused" do
      [@consulting.id, @archived.id, 0].each do |offer_id|
        get new_admin_event_path(offer_id: offer_id)

        assert_response :unprocessable_content
        assert_select ".alert", text: /Bitte ein Angebot auswählen/
      end
    end

    test "the new event belongs to the chosen offer and opens globally" do
      post admin_offer_events_path(@offer),
           params: {event: {date_and_time: "2026-12-01T10:00", max_no_of_participants: 10}}

      event = @offer.events.last

      assert_redirected_to edit_admin_offer_event_path(@offer, event)
    end

    test "the breadcrumb of the choice leads back to the event list" do
      get new_admin_event_path

      assert_equal ["Termine", "Neuer Termin"], controller.breadcrumb.pluck(:label)
    end

  end
end
