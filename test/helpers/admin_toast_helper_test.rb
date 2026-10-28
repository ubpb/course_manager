require "test_helper"

# The colors of the admin's toasts and which of them stay until closed.
class AdminToastHelperTest < ActionView::TestCase

  test "admin_toast_color follows the colors of the alerts" do
    assert_equal(["success", "info", "info", "warning", "warning", "danger", "primary"],
                 [:success, :notice, :info, :alert, :warning, :error, :other].map { admin_toast_color(it) })
  end

  test "admin_toast_sticky? keeps warnings and errors until they are closed" do
    assert_equal([false, false, false, true, true, true],
                 ["success", "notice", "info", "alert", "warning", "error"].map { admin_toast_sticky?(it) })
  end

end
