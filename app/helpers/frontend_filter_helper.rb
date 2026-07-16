module FrontendFilterHelper

  # Active filters for the offers index as a list of chip hashes
  # ({ label:, remove_path: }) for rendering by the shared active_filters partial.
  def frontend_offer_filter_chips(filter)
    return [] unless filter&.active?

    chips = []
    if filter.scope.present?
      label = case filter.scope
              when "courses" then "Schulungen"
              when "consultings" then "Beratungen"
              when "self_study_courses" then "Selbstlernkurse"
              else filter.scope
              end
      chips << { label: label,
                 remove_path: filter_remove_path(filter, :scope) }
    end
    if filter.with_upcoming_events
      chips << { label: "Mit anstehenden Terminen",
                 remove_path: filter_remove_path(filter, :with_upcoming_events) }
    end
    if filter.title.present?
      chips << { label: "Titel: #{filter.title}", remove_path: filter_remove_path(filter, :title) }
    end

    chips + frontend_topic_and_target_group_chips(filter)
  end

  # Active filters for the events index (see #frontend_offer_filter_chips).
  def frontend_event_filter_chips(filter)
    return [] unless filter&.active?

    chips = []
    if filter.title.present?
      chips << { label: "Titel: #{filter.title}", remove_path: filter_remove_path(filter, :title) }
    end
    unless filter.online.nil?
      chips << { label: (filter.online ? "Online" : "Präsenz"),
                 remove_path: filter_remove_path(filter, :online) }
    end
    if filter.date_range.present?
      labels = { "week" => "Diese Woche", "month" => "Dieser Monat", "quarter" => "Dieses Quartal" }
      chips << { label: labels.fetch(filter.date_range.to_s, filter.date_range),
                 remove_path: filter_remove_path(filter, :date_range) }
    end

    chips + frontend_topic_and_target_group_chips(filter)
  end

  private

  # Topic and target-group chips are shared by both offers and events.
  def frontend_topic_and_target_group_chips(filter)
    topics = Topic.where(id: filter.topics).order(:position).map do |topic|
      { label: "Thema: #{topic.title}", remove_path: filter_remove_path(filter, :topics, topic.id) }
    end
    target_groups = TargetGroup.where(id: filter.target_groups).order(:position).map do |tg|
      { label: "Zielgruppe: #{tg.title}", remove_path: filter_remove_path(filter, :target_groups, tg.id) }
    end

    topics + target_groups
  end

end
