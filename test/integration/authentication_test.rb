require "test_helper"

# What the login is expected to do to the session besides signing the user in.
class AuthenticationTest < ActionDispatch::IntegrationTest

  setup do
    @offer = Offer.create!(title: "Testkurs", type: "course", published: true)
  end

  def log_in
    post session_path, params: {login: {user_id: AlmaAuthenticationStub::VALID_USER_ID,
                                        password: AlmaAuthenticationStub::VALID_PASSWORD}}
  end

  # Persists a filter for the offers list in the session.
  def set_offers_filter
    get frontend_offers_path(filter: {scope: "courses"})
    follow_redirect!
  end

  # The session cookie always changes here, simply because its contents do, so it
  # says nothing about a rotation. Compare the session id -- by value: two
  # Rack::Session::SessionId objects for one and the same session are never `==`.
  def session_id
    session.id&.public_id
  end

  test "the login rotates the session id" do
    set_offers_filter
    before = session_id
    assert before.present?

    log_in

    assert_not_equal before, session_id
  end

  test "the logout rotates the session id" do
    log_in
    follow_redirect!
    before = session_id
    assert before.present?

    get logout_path

    assert_not_equal before, session_id
  end

  # Anything that is not explicitly carried over is dropped by the rotation.
  test "the login drops unrelated session data" do
    post admin_session_path, params: {login: {user_id: AlmaAuthenticationStub::VALID_USER_ID,
                                              password: AlmaAuthenticationStub::VALID_PASSWORD}}
    assert_redirected_to admin_root_path

    log_in

    assert_nil session[:current_admin_user_id]
  end

  test "the login keeps the user signed in across the rotation" do
    log_in
    follow_redirect!

    get account_root_path

    assert_response :success
  end

  test "list filters survive the login" do
    set_offers_filter
    assert_equal({"scope" => "courses"}, session["frontend/offers/filter"])

    log_in

    assert_equal({"scope" => "courses"}, session["frontend/offers/filter"])
  end

  test "list filters survive the logout" do
    log_in
    follow_redirect!
    set_offers_filter

    get logout_path

    assert_equal({"scope" => "courses"}, session["frontend/offers/filter"])
  end

  test "the login is rate limited" do
    10.times do
      post session_path, params: {login: {user_id: "nobody", password: "wrong"}}
      assert_response :unprocessable_entity
    end

    post session_path, params: {login: {user_id: "nobody", password: "wrong"}}

    assert_redirected_to new_session_path
    assert_equal I18n.t("sessions.create.rate_limited"), flash[:alert]
  end

  test "the rate limit blocks a correct password too" do
    11.times { post session_path, params: {login: {user_id: "nobody", password: "wrong"}} }

    log_in

    assert_redirected_to new_session_path
  end

end
