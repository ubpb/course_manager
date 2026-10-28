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

end
