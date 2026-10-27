require "test_helper"

# Every part of an event -- participants, statistics, certificate and the
# event data -- shows under one head with tabs, so staff switch between them
# with one click and always see which event they are working on.
class Admin::EventPageTest < ActionDispatch::IntegrationTest

  include ActionView::RecordIdentifier
  include AdminLogin
  include MailerRecords
  include ReportRecords

  setup do
    @offer = create_offer
    @event = create_event

    log_in_admin
  end

  test "every part of an event shows the head and marks its tab" do
    registration = create_registration

    {admin_offer_event_registrations_path(@offer, @event) => "Teilnehmer",
     new_admin_offer_event_registration_path(@offer, @event) => "Teilnehmer",
     edit_admin_offer_event_registration_path(@offer, @event, registration) => "Teilnehmer",
     new_admin_offer_event_report_path(@offer, @event) => "Statistik",
     new_admin_offer_event_certification_path(@offer, @event) => "Zertifikat",
     edit_admin_offer_event_path(@offer, @event) => "Termindaten"}.each do |path, tab|
      get path

      assert_select ".context-head-event", {text: /Literaturrecherche/}, "for #{path}"
      assert_select ".event-tabs .nav-link.active", {text: /#{tab}/}, "for #{path}"
    end
  end

  test "the head shows date, capacity and the participant count" do
    create_registration
    get admin_offer_event_registrations_path(@offer, @event)

    assert_select ".context-head-event .context-head-date", text: "Do, 15.10.2026"
    assert_select ".context-head-event .context-head-time", text: "10:00–11:30 Uhr"
    assert_select ".context-head-event .badge", text: "1 / 10 Plätze"
    assert_select ".event-tabs .nav-link", text: /Teilnehmer\s*1/
  end

  test "the statistics badge appears for past events only" do
    @event.update!(date_and_time: 1.week.from_now)
    get admin_offer_event_registrations_path(@offer, @event)

    assert_select ".context-head-event .badge", text: /Statistik/, count: 0

    @event.update!(date_and_time: 1.week.ago)
    get admin_offer_event_registrations_path(@offer, @event)

    assert_select ".context-head-event .badge", text: "keine Statistik"

    create_report
    get admin_offer_event_registrations_path(@offer, @event)

    assert_select ".context-head-event .badge", text: "Statistik erfasst"
  end

  test "the offer context bar shows only in the offer context" do
    get admin_offer_event_registrations_path(@offer, @event)

    assert_select ".offer-context-bar", count: 0

    back = admin_offer_events_path(@offer, anchor: dom_id(@event))
    get admin_offer_event_registrations_path(@offer, @event, nav_scope: "offer")

    assert_select ".offer-context-bar a[href=?]", back
  end

  test "the offer context names the way back once" do
    get admin_offer_event_registrations_path(@offer, @event, nav_scope: "offer")

    assert_select "a", text: /Zurück zum Angebot/, count: 1
  end

  test "an archived offer still opens, without a link to the front end" do
    get admin_offer_event_registrations_path(@offer, @event)

    assert_select ".context-head-event a[href=?]", frontend_offer_path(@offer)

    @offer.update!(archived: true)
    get admin_offer_event_registrations_path(@offer, @event)

    assert_response :success
    assert_select ".context-head-event .badge", text: "archiviert"
    assert_select ".context-head-event a[href=?]", frontend_offer_path(@offer), count: 0
  end

  test "an invalid date keeps the page intact" do
    patch admin_offer_event_path(@offer, @event), params: {event: {date_and_time: ""}}

    assert_response :unprocessable_content
    assert_select ".context-head-event", text: /Do, 15\.10\.2026/
    assert_select ".event-tabs .nav-link.active", text: "Termindaten"
  end

  test "the cards no longer close with an x" do
    get edit_admin_offer_event_path(@offer, @event)

    assert_select ".card-header .fa-times", count: 0
    assert_select ".card-title", text: "Termindaten"
  end

end
