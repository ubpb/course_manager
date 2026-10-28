require "application_system_test_case"

# Forms and dialogs open as modals on top of a page, streamed in by Turbo.
# Whether they are closed or removed by a refresh, they must go away without
# leaving anything behind.
class ModalsTest < ApplicationSystemTestCase

  setup { log_in_admin }

  test "a modal removed while open leaves no script error behind" do
    visit admin_topics_path
    collect_script_errors

    find("a[href='#{new_admin_topic_path}']").click
    # The field gets the focus once the modal is fully open. Before that,
    # Bootstrap ignores any attempt to hide it.
    assert_selector "#topic_title:focus"
    fill_in "Titel", with: "Neu"
    click_on "Speichern"

    # Saving refreshes the list, which removes the open modal.
    assert_selector "li", text: "Neu"
    assert_no_selector ".modal, .modal-backdrop", visible: :all
    assert_empty script_errors
  end

  test "a closed modal leaves nothing behind" do
    visit admin_topics_path
    collect_script_errors

    find("a[href='#{new_admin_topic_path}']").click

    assert_selector "#topic_title:focus"
    click_on "Abbrechen"

    assert_no_selector ".modal, .modal-backdrop", visible: :all
    assert_no_selector "body.modal-open"
    assert_empty script_errors
  end

  private

  def collect_script_errors
    execute_script(<<~JS)
      window.scriptErrors = [];
      window.addEventListener("error", (event) => window.scriptErrors.push(event.message));
    JS
  end

  # Bootstrap finishes hiding a modal after its fade transition (0.3 s), so
  # wait that out before looking.
  def script_errors
    evaluate_async_script("const done = arguments[0]; setTimeout(() => done(window.scriptErrors), 500)")
  end

end
