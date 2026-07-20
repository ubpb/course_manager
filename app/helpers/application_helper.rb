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

  # Per-page <title> content. An explicit `content_for :page_title` wins;
  # otherwise fall back to the deepest breadcrumb label (set in controllers).
  def page_title
    content_for(:page_title).presence || breadcrumb.last&.dig(:label)
  end

  # Markdown → rendered HTML → plain text, whitespace-collapsed.
  # Used to turn offer body copy into meta-description-safe text.
  def strip_markdown(text)
    return "" if text.blank?

    strip_tags(render_markdown(text)).squish
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
