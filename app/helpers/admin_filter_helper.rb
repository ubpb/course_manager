module AdminFilterHelper

  # Active filters for the admin offers index as a list of chip hashes
  # ({ label:, remove_path: }) for rendering by the shared _filter_bar partial.
  def admin_offer_filter_chips(filter)
    return [] unless filter&.active?

    chips = []
    if filter.scope.present?
      chips << { label: (filter.scope == "courses" ? "Kurse" : "Beratungen"),
                 remove_path: filter_remove_path(filter, :scope) }
    end
    unless filter.published.nil?
      chips << { label: "Veröffentlicht: #{filter.published ? "Ja" : "Nein"}",
                 remove_path: filter_remove_path(filter, :published) }
    end
    if filter.title.present?
      chips << { label: "Titel: #{filter.title}", remove_path: filter_remove_path(filter, :title) }
    end
    if filter.include_archived
      chips << { label: "Archivierte anzeigen", remove_path: filter_remove_path(filter, :include_archived) }
    end

    chips
  end

  # Active filters for the admin events index (see #admin_offer_filter_chips).
  def admin_event_filter_chips(filter)
    return [] unless filter&.active?

    chips = []
    if filter.upcoming_or_past.present? && filter.upcoming_or_past != "all"
      labels = {
        "upcoming" => "Kommende Termine",
        "upcoming_and_last_3_months" => "Kommende + letzte 3 Monate",
        "past" => "Vergangene Termine"
      }
      chips << { label: labels.fetch(filter.upcoming_or_past.to_s, filter.upcoming_or_past),
                 remove_path: filter_remove_path(filter, :upcoming_or_past) }
    end
    unless filter.published.nil?
      chips << { label: "Veröffentlicht: #{filter.published ? "Ja" : "Nein"}",
                 remove_path: filter_remove_path(filter, :published) }
    end
    unless filter.online.nil?
      chips << { label: (filter.online ? "Online" : "Präsenz"),
                 remove_path: filter_remove_path(filter, :online) }
    end
    unless filter.with_report.nil?
      chips << { label: (filter.with_report ? "Mit Bericht" : "Ohne Bericht"),
                 remove_path: filter_remove_path(filter, :with_report) }
    end
    if filter.title.present?
      chips << { label: "Titel: #{filter.title}", remove_path: filter_remove_path(filter, :title) }
    end
    if filter.from_date.present?
      chips << { label: "Ab #{I18n.l(filter.from_date)}", remove_path: filter_remove_path(filter, :from_date) }
    end
    if filter.to_date.present?
      chips << { label: "Bis #{I18n.l(filter.to_date)}", remove_path: filter_remove_path(filter, :to_date) }
    end

    chips
  end

end
