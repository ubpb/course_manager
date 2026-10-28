module AdminNavigationHelper

  OFFER_TYPE_LABELS = {
    "course" => "Schulung",
    "consulting" => "Beratung",
    "self_study_course" => "Selbstlernkurs"
  }.freeze

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

  # The page the menu bar leads back to from another area (see the admin-nav
  # controller): the current one, unless it answers a form (HEAD is routed like
  # GET). Leading slashes are squeezed: "//admin/events" routes like
  # "/admin/events", but as a link it would lead to a host "admin".
  def admin_menu_resume_path
    request.fullpath.sub(%r{\A/+}, "/") if request.get? || request.head?
  end

  def offer_type_label(offer)
    OFFER_TYPE_LABELS.fetch(offer.type, offer.type)
  end

  # The way back from an event or offer page to where it was opened from.
  def back_link(label, path, **)
    link_to(path, **) do
      tag.i(class: "fa-solid fa-arrow-left me-1", "aria-hidden": true) + label
    end
  end

  # For offers and events alike.
  def published_badge(record)
    if record.published?
      tag.span("veröffentlicht", class: "status-badge status-published")
    else
      tag.span("nicht veröffentlicht", class: "status-badge status-unpublished")
    end
  end

  # "Do, 15.10.2026"
  def event_date(event)
    l(event.date_and_time, format: "%a, %d.%m.%Y")
  end

  # "10:00–11:30 Uhr", without a duration "10:00 Uhr".
  def event_time_span(event)
    start = event.date_and_time
    time = l(start, format: "%H:%M")
    time += "–#{l(start + event.duration.minutes, format: "%H:%M")}" if event.duration.to_i.positive?

    "#{time} Uhr"
  end

  def event_capacity(event)
    "#{event.registrations_count} / #{event.limited? ? event.max_no_of_participants : "∞"}"
  end

end
