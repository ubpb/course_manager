module ApplicationHelper

  def color_mode_enabled?
    ApplicationConfig[:color_mode, :enabled, default: false]
  end

  def locale_switching_enabled?
    ApplicationConfig[:locale_switching, :enabled, default: false]
  end

  def active_when(regexp_path_or_boolean)
    if regexp_path_or_boolean.is_a?(Regexp)
      regexp = regexp_path_or_boolean
      request.path&.match?(regexp) ? "active" : ""
    elsif regexp_path_or_boolean.is_a?(String)
      path = regexp_path_or_boolean
      request.path == path ? "active" : ""
    else
      bool = regexp_path_or_boolean
      bool == true ? "active" : ""
    end
  end

  def date_in_words(date)
    case date
    when Time.zone.today          then t("datetime.today")
    when Time.zone.today + 1.day  then t("datetime.tomorrow")
    when Time.zone.today + 2.days then t("datetime.day_after_tomorrow")
    else distance_of_time_in_words_to_now(date, scope: "datetime.distance_in_words.date_only")
    end
  end

  # Path that removes one filter key, or a single value from an array filter,
  # from the currently stored filter params. Shared by the frontend and admin
  # chip helpers. Falls back to a clean reset when no filters remain.
  def filter_remove_path(filter, key, value = nil)
    params = filter.params.deep_dup

    if value && params[key].is_a?(Array)
      params[key] = params[key].reject { |v| v.to_s == value.to_s }
      params.delete(key) if params[key].blank?
    else
      params.delete(key)
    end

    # Drop blank/nil-valued keys (e.g. the controller injects
    # `with_upcoming_events => nil`) so removing the last real filter falls
    # back to a clean reset. String "false" is not blank, so an active
    # `online=false` filter is preserved.
    params = params.reject { |_, v| v.blank? }

    params.present? ? url_for(filter: params) : url_for(reset_filter: true)
  end

  def render_markdown(text)
    Commonmarker.to_html(
      text,
      options: {
        parse: {smart: true},
        render: {hardbreaks: false}
      }
    )
  end

end
