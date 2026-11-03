# What the participant list and its export say about a participant's
# attendance: a no-show did not attend, whenever staff mark it; everyone else
# counts as attended once the event has begun. Before that, attendance is still
# open, so a list printed for the event claims nothing yet: the list shows a
# dash, the export a blank cell to fill in by hand.
module AdminAttendanceHelper

  def attendance_label(registration, before_event: "—")
    if registration.no_show?
      "Nein"
    elsif registration.event.date_and_time.future?
      before_event
    else
      "Ja"
    end
  end

end
