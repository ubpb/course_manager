module ApplicationHelper

  def color_mode_enabled?
    ApplicationConfig[:color_mode, :enabled, default: false]
  end

  def locale_switching_enabled?
    ApplicationConfig[:locale_switching, :enabled, default: false]
  end

end
