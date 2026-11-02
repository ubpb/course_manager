# What the participant list and its export say about a participant's
# attendance: a no-show did not attend, whenever staff mark it; everyone else
# counts as attended once the event has begun. Before that, attendance is still
# open, so a list printed for the event claims nothing yet.
module AdminAttendanceHelper

  def attendance_label(registration)
    if registration.no_show?
      "Nein"
    elsif registration.event.date_and_time.future?
      "—"
    else
      "Ja"
    end
  end

end
