require "application_system_test_case"

# Turbo morphs a page instead of replacing it when a visit replaces it with one
# of the same path, as a redirect back to a list does, and when a form is sent
# back with errors. The elements and their Stimulus controllers stay, but their
# markup goes back to the server's, so a controller sets up again what it had
# set up when it connected.
class PageMorphTest < ApplicationSystemTestCase

  include MailerRecords

  setup { log_in_admin }

  test "the colour mode button keeps its label when a list is morphed" do
    create_offer
    visit admin_offers_path

    assert_selector "#admin-navbar [data-color-mode-switcher-target=colorModeButton]", text: "Hell"

    execute_script(<<~JS)
      document.addEventListener("turbo:render", (event) => { window.renderMethod = event.detail.renderMethod }, {once: true});
    JS
    first("input[name='bulk_process_ids[]']").click
    select "Archivieren", from: "bulk_process_action"
    click_on "Ausführen"

    assert_selector "#admin-toasts .toast", text: "Angebot(e) wurde archiviert"
    assert_equal "morph", evaluate_script("window.renderMethod")
    assert_selector "#admin-navbar [data-color-mode-switcher-target=colorModeButton]", text: "Hell"
  end

end
