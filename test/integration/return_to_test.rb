require "test_helper"

# A page that needs a login remembers where the visitor wanted to go, but only
# a page to look at. A page that offers the login or the logout names where to
# come back to, but never another host.
class ReturnToTest < ActionDispatch::IntegrationTest

  # Each a way to send a visitor off to another host. Browsers drop tabs and
  # newlines from a URL, so "/<tab>/host" ends up as "//host".
  FOREIGN_PATHS = ["//evil.example", "https://evil.example/x", "/\\evil.example",
                   "/\t/evil.example", "/\n/evil.example"].freeze
  # Not a path a redirect can take.
  MALFORMED_PATHS = ["/angebote foo", "/ä"].freeze

  def log_in
    post session_path, params: {login: {user_id: AlmaAuthenticationStub::VALID_USER_ID,
                                        password: AlmaAuthenticationStub::VALID_PASSWORD}}
  end

  test "the login page remembers the page it is given and returns there" do
    get new_session_path(return_to: frontend_offers_path)

    assert_equal frontend_offers_path, session[:return_to]

    log_in

    assert_redirected_to frontend_offers_path
  end

  test "the login page ignores a page on another host or not a plain path" do
    (FOREIGN_PATHS + MALFORMED_PATHS + [["/angebote"]]).each do |path|
      get new_session_path(return_to: path)

      assert_nil session[:return_to], "#{path.inspect} was remembered"
    end
  end

  test "someone logged in is led from the login page to the page it is given" do
    log_in
    get new_session_path(return_to: frontend_offers_path)

    assert_redirected_to frontend_offers_path

    get new_session_path(return_to: "//evil.example")

    assert_redirected_to account_root_path
  end

  test "the logout leads to the page it is given" do
    log_in
    get logout_path(return_to: frontend_offers_path)

    assert_redirected_to frontend_offers_path

    (FOREIGN_PATHS + MALFORMED_PATHS).each do |path|
      log_in
      get logout_path(return_to: path)

      assert_redirected_to root_path
    end
  end

  test "the cancel button of the login page leads back to the remembered page" do
    get new_session_path(return_to: frontend_offers_path)

    assert_select "a[href=?]", frontend_offers_path, text: I18n.t("sessions.new.cancel")

    reset!
    get new_session_path

    assert_select "a[href=?]", root_path, text: I18n.t("sessions.new.cancel")
  end

  test "the account remembers itself as the way back" do
    get account_root_path

    assert_redirected_to new_session_path
    assert_equal account_root_path, session[:return_to]
  end

  test "a form sent while logged out is not remembered" do
    delete account_registration_path(1)

    assert_redirected_to new_session_path
    assert_nil session[:return_to]
  end

end
