module AdminFilterHelper

  # Active filters for the admin offers index as a list of chip hashes
  # ({ label:, remove_path: }) for rendering by the shared _filter_bar partial.
  def admin_offer_filter_chips(filter)
    filter_chips_for(filter, :scope, :published, :title, :include_archived)
  end

  # Active filters for the admin events index (see #admin_offer_filter_chips).
  def admin_event_filter_chips(filter)
    filter_chips_for(filter,
                     :upcoming_or_past, :published, :online, :with_report,
                     :title, :from_date, :to_date)
  end

end
