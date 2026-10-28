require "test_helper"

# Who gets in: every active library account to the account area, only active
# staff to the admin area. A failed login says so once and keeps the form.
class LoginTest < ActionDispatch::IntegrationTest

  STUB = AlmaAuthenticationStub

  def log_in(user_id, password = STUB::VALID_PASSWORD)
    post session_path, params: {login: {user_id: user_id, password: password}}
  end

  def log_in_admin(user_id, password = STUB::VALID_PASSWORD)
    post admin_session_path, params: {login: {user_id: user_id, password: password}}
  end

  test "any active library account logs in to the account area" do
    log_in(STUB::PATRON_USER_ID)

    assert_redirected_to account_root_path
  end

  test "an inactive account stays out of the account area" do
    log_in(STUB::INACTIVE_USER_ID)

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sessions.create.failed")
  end

  test "without Alma the login says it is not possible right now" do
    log_in(STUB::UNAVAILABLE_USER_ID)

    assert_response :service_unavailable
    assert_select ".alert", text: I18n.t("sessions.create.unavailable")
    assert_select "form[action=?]", session_path
  end

  test "without Alma the admin login says it is not possible right now" do
    log_in_admin(STUB::UNAVAILABLE_USER_ID)

    assert_response :service_unavailable
    assert_select ".alert", text: /Bibliothekssystem nicht erreichbar/
    assert_select "form[action=?]", admin_session_path
  end

  test "the login form without user or password is shown again" do
    log_in("", "")

    assert_redirected_to new_session_path
  end

  test "someone logged in is led from the login to the account" do
    log_in(STUB::VALID_USER_ID)
    get new_session_path

    assert_redirected_to account_root_path
  end

  test "only active staff log in to the admin area" do
    [STUB::PATRON_USER_ID, STUB::INACTIVE_USER_ID].each do |user_id|
      log_in_admin(user_id)

      assert_response :unprocessable_content
      assert_select ".alert", text: /Fehler bei der Anmeldung/
    end

    log_in_admin(STUB::VALID_USER_ID)

    assert_redirected_to admin_root_path
  end

  test "a failed admin login shows its message only once" do
    log_in_admin(STUB::VALID_USER_ID, "falsch")

    assert_response :unprocessable_content

    get new_admin_session_path

    assert_select ".alert", text: /Fehler bei der Anmeldung/, count: 0
  end

  test "the admin login form without user or password is shown again" do
    log_in_admin("", "")

    assert_redirected_to new_admin_session_path
  end

  test "an admin logged in is led from the login to the admin area" do
    log_in_admin(STUB::VALID_USER_ID)
    get new_admin_session_path

    assert_redirected_to admin_root_path
  end

  test "the admin login is rate limited" do
    10.times { log_in_admin("nobody", "falsch") }

    log_in_admin(STUB::VALID_USER_ID)

    assert_redirected_to new_admin_session_path
    assert_match "Zu viele Anmeldeversuche", flash[:alert]
  end

  test "the admin login page forgets the admin filters of the tab" do
    get new_admin_session_path

    assert_select "[data-controller=filter-memory][data-filter-memory-forget-value='admin/']"
  end

end
