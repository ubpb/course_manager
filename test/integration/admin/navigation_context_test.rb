require "test_helper"

# An event is reached from the global event list or from the events of its
# offer. Wherever staff go inside the event, the way back and the breadcrumb
# lead to the list they came from.
class Admin::NavigationContextTest < ActionDispatch::IntegrationTest

  include ActionView::RecordIdentifier
  include AdminLogin
  include MailerRecords

  # After a request the path helpers of an integration test pick up the
  # controller's default URL options -- and with them the nav_scope of that
  # request. Expected paths are therefore built before the request.

  setup do
    @offer = create_offer
    @event = create_event

    log_in_admin
  end

  test "an event page outside the offer context leads back to the event list" do
    get admin_offer_event_registrations_path(@offer, @event)

    assert_select "a[href=?]", admin_events_path(anchor: dom_id(@event))
  end

  test "an event page in the offer context leads back to the offer" do
    back = admin_offer_events_path(@offer, anchor: dom_id(@event))
    get admin_offer_event_registrations_path(@offer, @event, nav_scope: "offer")

    assert_select "a[href=?]", back
  end

  test "deleting an event returns to the list it came from" do
    delete admin_offer_event_path(@offer, @event)

    assert_redirected_to admin_events_path

    other = create_event
    back = admin_offer_events_path(@offer)
    delete admin_offer_event_path(@offer, other, nav_scope: "offer")

    assert_redirected_to back
  end

  test "the breadcrumb of a global event starts with the event list" do
    get admin_offer_event_report_path(@offer, @event)
    follow_redirect!

    assert_equal ["Termine", "15.10.2026, 10:00 · Literaturrecherche", "Statistik"],
                 controller.breadcrumb.pluck(:label).last(3)
  end

  test "the breadcrumb in the offer context starts with the offers" do
    get admin_offer_event_registrations_path(@offer, @event, nav_scope: "offer")

    assert_equal ["Angebote", "Literaturrecherche", "15.10.2026, 10:00", "Teilnehmer"],
                 controller.breadcrumb.pluck(:label).last(4)
  end

  test "the participant crumb points to the participant" do
    registration = create_registration
    get edit_admin_offer_event_registration_path(@offer, @event, registration)

    assert_equal({label: "Mustermann, Max",
                  path: edit_admin_offer_event_registration_path(@offer, @event, registration)},
                 controller.breadcrumb.last)
    assert_equal "Teilnehmer", controller.breadcrumb[-2][:label]
  end

  test "the offer's event list leads into its events in the offer context" do
    get admin_offer_events_path(@offer)

    assert_select "a[href=?]", admin_offer_event_registrations_path(@offer, @event, nav_scope: "offer")
  end

  test "the global event list leads into events without a context" do
    get admin_events_path

    assert_select "a[href=?]", admin_offer_event_registrations_path(@offer, @event)
    assert_select "a[href*='nav_scope']", count: 0
  end

  test "actions inside an event keep the offer context" do
    registration = create_registration
    patch send_reminder_message_admin_offer_event_registration_path(@offer, @event, registration, nav_scope: "offer")

    assert_redirected_to admin_offer_event_registrations_path(@offer, @event, nav_scope: "offer")
  end

end
