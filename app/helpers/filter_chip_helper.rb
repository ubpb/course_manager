module FilterChipHelper

  # Render the given filter keys, in order, into a flat list of chip hashes
  # ({ label:, remove_path: }) for the shared _filter_bar partial. Inactive
  # filters are skipped; a key may yield zero, one, or several chips (:topics,
  # :target_groups). Shared by the frontend and admin helpers.
  def filter_chips_for(filter, *keys)
    return [] unless filter&.active?

    keys.flatten.flat_map { |key| Array.wrap(filter_chip(filter, key)) }
  end

  private

  def filter_chip(filter, key)
    case key
    when :scope
      return if filter.scope.blank?

      labels = { "courses" => "Schulungen", "consultings" => "Beratungen", "self_study_courses" => "Selbstlernkurse" }
      chip(labels.fetch(filter.scope.to_s, filter.scope), filter, :scope)
    when :title
      chip("Titel: #{filter.title}", filter, :title) if filter.title.present?
    when :online
      chip(filter.online ? "Online" : "Präsenz", filter, :online) unless filter.online.nil?
    when :published
      chip("Veröffentlicht: #{filter.published ? "Ja" : "Nein"}", filter, :published) unless filter.published.nil?
    when :with_upcoming_events
      chip("Mit anstehenden Terminen", filter, :with_upcoming_events) if filter.with_upcoming_events
    when :with_report
      chip(filter.with_report ? "Mit Bericht" : "Ohne Bericht", filter, :with_report) unless filter.with_report.nil?
    when :include_archived
      chip("Archivierte anzeigen", filter, :include_archived) if filter.include_archived
    when :upcoming_or_past
      return if filter.upcoming_or_past.blank? || filter.upcoming_or_past == "all"

      labels = {
        "upcoming" => "Kommende Termine",
        "upcoming_and_last_3_months" => "Kommende + letzte 3 Monate",
        "past" => "Vergangene Termine"
      }
      chip(labels.fetch(filter.upcoming_or_past.to_s, filter.upcoming_or_past), filter, :upcoming_or_past)
    when :from_date
      chip("Ab #{I18n.l(filter.from_date)}", filter, :from_date) if filter.from_date.present?
    when :to_date
      chip("Bis #{I18n.l(filter.to_date)}", filter, :to_date) if filter.to_date.present?
    when :topics
      Topic.where(id: filter.topics).order(:position).map { |t| chip("Thema: #{t.title}", filter, :topics, t.id) }
    when :target_groups
      TargetGroup.where(id: filter.target_groups).order(:position).map { |tg| chip("Zielgruppe: #{tg.title}", filter, :target_groups, tg.id) }
    end
  end

  def chip(label, filter, key, value = nil)
    { label: label, remove_path: filter_remove_path(filter, key, value) }
  end

  # Path that removes one filter key, or a single value from an array filter,
  # from the currently stored filter params. Shared by the frontend and admin
  # chip helpers. Falls back to a clean reset when no filters remain.
  # Filterable only persists params that carry a value, so what is left here is
  # exactly the still-set filters.
  def filter_remove_path(filter, key, value = nil)
    params = filter.params.deep_dup

    if value && params[key].is_a?(Array)
      params[key] = params[key].reject { |v| v.to_s == value.to_s }
      params.delete(key) if params[key].blank?
    else
      params.delete(key)
    end

    params.present? ? url_for(filter: params) : url_for(reset_filter: true)
  end

end
