module AdminNavigationHelper

  # The area of the admin menu bar the current page belongs to. Events opened
  # from the events of their offer belong to the offers.
  def admin_menu_section
    if controller_path.in?(["admin/topics", "admin/target_groups"])
      :master_data
    elsif controller_path == "admin/offers" || offer_page? || offer_context?
      :offers
    else
      :events
    end
  end

end
