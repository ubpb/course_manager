require "test_helper"

# date_in_words counts calendar days. Measured from the current time of day
# instead, an afternoon visitor lost almost a whole day to rounding: an event
# in three days read "in 2 Tagen".
class ApplicationHelperTest < ActionView::TestCase

  setup { travel_to Time.zone.parse("2026-10-20 16:08") }

  # The controller provides the breadcrumb to the views.
  def breadcrumb = @breadcrumb || []

  def in_days(count)
    date_in_words(Time.zone.today + count.days)
  end

  test "the next two days have names" do
    assert_equal "Heute", in_days(0)
    assert_equal "Morgen", in_days(1)
    assert_equal "Übermorgen", in_days(2)
  end

  test "later days are counted in calendar days, whatever the time of day" do
    assert_equal "in 3 Tagen", in_days(3)
    assert_equal "in 15 Tagen", in_days(15)
    assert_equal "in 29 Tagen", in_days(29)
  end

  test "the same day is counted the same in the morning and in the evening" do
    travel_to Time.zone.parse("2026-10-20 00:05")
    morning = in_days(10)
    travel_to Time.zone.parse("2026-10-20 23:55")

    assert_equal morning, in_days(10)
  end

  # Across the change to winter time on 2026-10-25 a day is 25 hours long.
  test "a change of daylight saving time does not shift the count" do
    assert_equal "in 7 Tagen", in_days(7)
  end

  test "render_markdown joins single line breaks into one paragraph by default" do
    assert_equal "<p>Zeile 1\nZeile 2</p>\n", render_markdown("Zeile 1\nZeile 2")
  end

  test "render_markdown keeps single line breaks when asked to" do
    assert_includes render_markdown("Zeile 1\nZeile 2", hardbreaks: true), "Zeile 1<br />\nZeile 2"
  end

  test "distant dates fall back to months and years" do
    assert_equal "in 2 Monaten", in_days(61)
    assert_equal "in etwa einem Jahr", in_days(366)
  end

  test "active_when matches the path by pattern or exactly, or takes a condition" do
    request.path_info = "/admin/offers/42/edit"

    assert_equal "active", active_when(%r{\A/admin/offers})
    assert_equal "", active_when(%r{\A/admin/events})
    assert_equal "active", active_when("/admin/offers/42/edit")
    assert_equal "", active_when("/admin/offers")
    assert_equal "active", active_when(true)
    assert_equal "", active_when(false)
    assert_equal "", active_when(nil)
  end

  test "strip_markdown leaves plain text in one line" do
    assert_equal "Titel Ein fetter Satz.", strip_markdown("# Titel\n\nEin **fetter**\nSatz.")
    assert_equal "", strip_markdown(nil)
  end

  test "the page title is the deepest breadcrumb unless a page sets its own" do
    @breadcrumb = [{label: "Angebote"}, {label: "Literaturrecherche"}]

    assert_equal "Literaturrecherche", page_title

    content_for(:page_title, "Eigener Titel")

    assert_equal "Eigener Titel", page_title
  end

end
