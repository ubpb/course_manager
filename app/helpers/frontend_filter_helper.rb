module FrontendFilterHelper

  # Active filters for the offers index as a list of chip hashes
  # ({ label:, remove_path: }) for rendering by the shared _filter_bar partial.
  def frontend_offer_filter_chips(filter)
    filter_chips_for(filter, :scope, :with_upcoming_events, :title, :topics, :target_groups)
  end

  # The offers index filtered by the given raw filter params, by its canonical
  # URL.
  def frontend_offers_filtered_path(**params)
    with_filter_query(frontend_offers_path, Frontend::OffersController.filter_query(:offers, params))
  end

end
