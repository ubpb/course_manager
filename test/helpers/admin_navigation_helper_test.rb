require "test_helper"

class AdminNavigationHelperTest < ActionView::TestCase

  test "event_capacity shows the limit or infinity" do
    assert_equal "3 / 20", event_capacity(Event.new(registrations_count: 3, max_no_of_participants: 20))
    assert_equal "3 / ∞", event_capacity(Event.new(registrations_count: 3, max_no_of_participants: 0))
  end

  test "admin_menu_resume_path is the page with its query" do
    request.path = "/admin/events"
    request.query_string = "period=past"

    assert_equal "/admin/events?period=past", admin_menu_resume_path
  end

  test "admin_menu_resume_path is the page for a HEAD, which is routed like a GET" do
    request.path = "/admin/events"
    request.request_method = "HEAD"

    assert_equal "/admin/events", admin_menu_resume_path
  end

  test "admin_menu_resume_path is nothing for the answer to a form" do
    request.path = "/admin/offers/1"
    request.request_method = "PATCH"

    assert_nil admin_menu_resume_path
  end

  # "//admin/events" routes like "/admin/events", but as a link it would lead
  # to a host "admin".
  test "admin_menu_resume_path stays on this site" do
    request.path = "//admin/events"

    assert_equal "/admin/events", admin_menu_resume_path
  end

  test "offer_type_label translates the type" do
    assert_equal(["Schulung", "Beratung", "Selbstlernkurs"],
                 Offer::TYPES.map { |type| offer_type_label(Offer.new(type: type)) })
  end

  test "published_badge tells published from unpublished" do
    assert_dom_equal '<span class="status-badge status-published">veröffentlicht</span>',
                     published_badge(Offer.new(published: true))
    assert_dom_equal '<span class="status-badge status-unpublished">nicht veröffentlicht</span>',
                     published_badge(Event.new(published: false))
  end

  test "back_link leads back with an arrow" do
    assert_dom_equal '<a class="text-nowrap" href="/admin/events">' \
                     '<i class="fa-solid fa-arrow-left me-1" aria-hidden="true"></i>Zurück zur Terminliste</a>',
                     back_link("Zurück zur Terminliste", "/admin/events", class: "text-nowrap")
  end

  test "event_date and event_time_span split the heading" do
    event = Event.new(date_and_time: Time.zone.parse("2026-10-15 10:00"), duration: 90)

    assert_equal "Do, 15.10.2026", event_date(event)
    assert_equal "10:00–11:30 Uhr", event_time_span(event)

    event.duration = nil

    assert_equal "10:00 Uhr", event_time_span(event)
  end

end
