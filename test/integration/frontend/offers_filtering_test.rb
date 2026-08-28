require "test_helper"

# The filter round trip on the public offers index: filter params are persisted
# in the session, the request redirects to the clean list URL, and the next
# render reflects exactly the filters that are still set.
class Frontend::OffersFilteringTest < ActionDispatch::IntegrationTest

  setup do
    @scheduled_course = Offer.create!(title: "Testangebot mit Termin", type: "course", published: true)
    @unscheduled_course = Offer.create!(title: "Testangebot ohne Termin", type: "course", published: true)
    @consulting = Offer.create!(title: "Testberatung", type: "consulting", published: true)

    @scheduled_course.events.create!(date_and_time: 1.week.from_now,
                                    max_no_of_participants: 10,
                                    published: true)
  end

  def filter(params)
    get frontend_offers_path(filter: params)
    assert_redirected_to frontend_offers_path
    follow_redirect!
  end

  # Titles are matched against the rendered page, so they must not occur in the
  # page chrome ("Beratung" would match the "Beratungsangebote" heading).
  def listed
    [@scheduled_course, @unscheduled_course, @consulting].select { |offer| response.body.include?(offer.title) }
  end

  test "the scope filter alone" do
    filter(scope: "courses")

    assert_equal [@scheduled_course, @unscheduled_course], listed
  end

  test "the scope filter combined with with_upcoming_events" do
    filter(scope: "courses", with_upcoming_events: "1")

    assert_equal [@scheduled_course], listed
  end

  test "unchecking with_upcoming_events stops filtering by it" do
    filter(scope: "courses", with_upcoming_events: "1")
    assert_equal [@scheduled_course], listed

    # What an unchecked simple_form checkbox submits.
    filter(scope: "courses", with_upcoming_events: "0")

    assert_equal [@scheduled_course, @unscheduled_course], listed
  end

  test "with_upcoming_events is ignored outside the courses scope" do
    filter(scope: "consultings", with_upcoming_events: "1")

    assert_equal [@consulting], listed
  end

  test "filters survive the next request and reset_filter clears them" do
    filter(scope: "courses", with_upcoming_events: "1")

    get frontend_offers_path
    assert_equal [@scheduled_course], listed

    get frontend_offers_path(reset_filter: true)
    assert_redirected_to frontend_offers_path
    follow_redirect!

    assert_equal [@scheduled_course, @unscheduled_course, @consulting], listed
  end

  test "blank filter values are not persisted" do
    filter(scope: "courses", title: "")

    get frontend_offers_path
    assert_equal [@scheduled_course, @unscheduled_course], listed

    filter(scope: "", title: "")

    assert_equal [@scheduled_course, @unscheduled_course, @consulting], listed
  end

  test "removing a filter through its chip drops only that filter" do
    filter(scope: "courses", with_upcoming_events: "1")
    assert_equal [@scheduled_course], listed

    chip = css_select("span.badge").find { |badge| badge.text.include?("Mit anstehenden Terminen") }
    assert chip, "expected a chip for the with_upcoming_events filter"

    get chip.at_css("a")["href"]
    follow_redirect!

    assert_equal [@scheduled_course, @unscheduled_course], listed
    assert_empty css_select("span.badge").select { |badge| badge.text.include?("Mit anstehenden Terminen") }
  end

  test "an unset filter has no chip" do
    filter(scope: "courses", with_upcoming_events: "0")

    assert_empty css_select("span.badge").select { |badge| badge.text.include?("Mit anstehenden Terminen") }
  end

  test "a filter param that is not a hash does not raise" do
    get frontend_offers_path(filter: "nonsense")

    assert_response :success
  end

end
