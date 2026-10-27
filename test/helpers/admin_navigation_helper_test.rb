require "test_helper"

class AdminNavigationHelperTest < ActionView::TestCase

  test "event_heading names weekday, date and time span" do
    event = Event.new(date_and_time: Time.zone.parse("2026-10-15 10:00"), duration: 90)

    assert_equal "Do, 15.10.2026 · 10:00–11:30 Uhr", event_heading(event)

    event.duration = nil

    assert_equal "Do, 15.10.2026 · 10:00 Uhr", event_heading(event)
  end

  test "event_capacity shows the limit or infinity" do
    assert_equal "3 / 20", event_capacity(Event.new(registrations_count: 3, max_no_of_participants: 20))
    assert_equal "3 / ∞", event_capacity(Event.new(registrations_count: 3, max_no_of_participants: 0))
  end

  test "offer_type_label translates the type" do
    assert_equal ["Schulung", "Beratung", "Selbstlernkurs"],
                 Offer::TYPES.map { |type| offer_type_label(Offer.new(type: type)) }
  end

  test "published_badge tells published from unpublished" do
    assert_dom_equal '<span class="status-badge status-published">veröffentlicht</span>',
                     published_badge(Offer.new(published: true))
    assert_dom_equal '<span class="status-badge status-unpublished">nicht veröffentlicht</span>',
                     published_badge(Event.new(published: false))
  end

  test "event_date and event_time_span split the heading" do
    event = Event.new(date_and_time: Time.zone.parse("2026-10-15 10:00"), duration: 90)

    assert_equal "Do, 15.10.2026", event_date(event)
    assert_equal "10:00–11:30 Uhr", event_time_span(event)
  end

end
