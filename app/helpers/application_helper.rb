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

end
