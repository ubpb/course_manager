require "test_helper"

# The toasts of the admin: one per message left in the flash, stacked in the
# order of the flash, each taken out of it.
module Admin
  class ToastsViewTest < ActionView::TestCase

    test "several messages stack as toasts of their own" do
      flash[:success] = "Termin(e) wurde(n) veröffentlicht"
      flash[:alert] = "Bitte Termine und Ziel-Angebot auswählen"

      render partial: "admin/application/toasts"

      assert_select "#admin-toasts .toast-container > .toast", count: 2
      assert_select ".toast:nth-child(1)[role=status]", text: /veröffentlicht/
      assert_select ".toast:nth-child(2)[role=alert]", text: /Ziel-Angebot/
      assert_equal 2, css_select(".toast").pluck("id").uniq.size
      assert_empty flash.keys
    end

  end
end
