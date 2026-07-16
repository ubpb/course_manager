module FrontendFilterHelper

  # Active filters for the offers index as a list of chip hashes
  # ({ label:, remove_path: }) for rendering by the shared _filter_bar partial.
  def frontend_offer_filter_chips(filter)
    filter_chips_for(filter, :scope, :with_upcoming_events, :title, :topics, :target_groups)
  end

  # Active filters for the events index (see #frontend_offer_filter_chips).
  def frontend_event_filter_chips(filter)
    filter_chips_for(filter, :title, :online, :date_range, :topics, :target_groups)
  end

end
