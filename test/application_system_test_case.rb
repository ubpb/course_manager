require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase

  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]

  # Signs in to the admin area through the login form, with Alma stubbed out
  # (see AlmaAuthenticationStub).
  def log_in_admin
    visit new_admin_session_path
    fill_in "Alma Benutzername", with: AlmaAuthenticationStub::VALID_USER_ID
    fill_in "Alma Passwort", with: AlmaAuthenticationStub::VALID_PASSWORD
    click_on "Anmelden"

    assert_no_current_path new_admin_session_path
  end

  # Records the script errors of the current page, read with #script_errors.
  def collect_script_errors
    execute_script(<<~JS)
      window.scriptErrors = [];
      window.addEventListener("error", (event) => window.scriptErrors.push(event.message));
    JS
  end

  def script_errors
    wait_for_transitions
    evaluate_script("window.scriptErrors")
  end

  # Bootstrap finishes showing or hiding a modal after its fade transition
  # (0.3 s), so wait that out before looking.
  def wait_for_transitions
    evaluate_async_script("setTimeout(arguments[0], 500)")
  end

end
