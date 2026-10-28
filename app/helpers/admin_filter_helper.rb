module AdminFilterHelper

  # The periods of the event lists' switch, as [label, value of upcoming_or_past,
  # tooltip or nil].
  EVENT_PERIODS = [
    ["Kommende", "upcoming"],
    ["Kommende + letzte 3 Monate", "upcoming_and_last_3_months", "Alle kommenden Termine und die der letzten 3 Monate"],
    ["Vergangene", "past"],
    ["Alle", "all"]
  ].freeze

  # Active filters for the admin offers index as a list of chip hashes
  # ({ label:, remove_path: }) for rendering by the shared _filter_bar partial.
  def admin_offer_filter_chips(filter)
    filter_chips_for(filter, :scope, :published, :title, :include_archived)
  end

  # Active filters for the admin events index (see #admin_offer_filter_chips).
  # The period is no chip, the period switch shows it.
  def admin_event_filter_chips(filter)
    filter_chips_for(filter,
                     :published, :online, :with_report,
                     :title, :from_date, :to_date)
  end

  # Path of the current event list with another period and all other filters
  # kept: storing filters replaces the stored ones as a whole.
  def admin_event_period_path(filter, value)
    url_for(filter: filter.params.merge("upcoming_or_past" => value))
  end

end
