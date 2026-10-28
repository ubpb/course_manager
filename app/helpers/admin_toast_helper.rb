# The admin shows its flash messages as toasts (admin/application/_toasts), in
# the colors the alerts use: success green, notices blue, warnings yellow,
# errors red. Warnings and errors stay until they are closed.
module AdminToastHelper

  TOAST_COLORS = {
    "success" => "success",
    "notice" => "info",
    "info" => "info",
    "alert" => "warning",
    "warning" => "warning",
    "error" => "danger"
  }.freeze

  STICKY_TOAST_TYPES = ["alert", "warning", "error"].freeze

  def admin_toast_color(type)
    TOAST_COLORS.fetch(type.to_s, "primary")
  end

  def admin_toast_sticky?(type)
    STICKY_TOAST_TYPES.include?(type.to_s)
  end

end
