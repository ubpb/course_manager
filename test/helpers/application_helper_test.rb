require "test_helper"

# date_in_words counts calendar days. Measured from the current time of day
# instead, an afternoon visitor lost almost a whole day to rounding: an event
# in three days read "in 2 Tagen".
class ApplicationHelperTest < ActionView::TestCase

  setup { travel_to Time.zone.parse("2026-10-20 16:08") }

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

  test "distant dates fall back to months and years" do
    assert_equal "in 2 Monaten", in_days(61)
    assert_equal "in etwa einem Jahr", in_days(366)
  end

end
