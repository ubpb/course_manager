require "test_helper"

# What the participant list and its export say about a participant's
# attendance.
class AdminAttendanceHelperTest < ActionView::TestCase

  def registration(starts:, no_show: false)
    Registration.new(event: Event.new(date_and_time: starts), no_show: no_show)
  end

  test "attendance_label leaves attendance open until the event begins" do
    assert_equal "—", attendance_label(registration(starts: 1.hour.from_now))
  end

  test "attendance_label puts what it is given in place of open attendance" do
    assert_nil attendance_label(registration(starts: 1.hour.from_now), before_event: nil)
  end

  test "attendance_label counts a participant as attended once the event has begun" do
    assert_equal "Ja", attendance_label(registration(starts: 1.hour.ago))
  end

  test "attendance_label names a no-show at any time" do
    assert_equal(["Nein", "Nein"],
                 [1.hour.from_now, 1.hour.ago].map { attendance_label(registration(starts: it, no_show: true)) })
  end

end
