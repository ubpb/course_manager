require "test_helper"

# Stub out the Alma round trip so the login can be driven from a test.
module AlmaAuthenticationStub

  VALID_USER_ID = "12345"
  VALID_PASSWORD = "secret"

  def authenticate_against_alma(user_id, password)
    user_id == VALID_USER_ID && password == VALID_PASSWORD
  end

  def fetch_alma_user(user_id)
    return nil unless user_id == VALID_USER_ID

    {
      "primary_id" => VALID_USER_ID,
      "first_name" => "Erika",
      "last_name" => "Mustermann",
      "status" => {"value" => "ACTIVE"},
      "contact_info" => {"email" => [{"preferred" => true, "email_address" => "erika@example.com"}]}
    }
  end

end

SessionsController.prepend(AlmaAuthenticationStub)

# Clicking "Jetzt anmelden" while logged out must lead back to the registration
# form after the login, not to the account page.
class Frontend::RegistrationLoginRedirectTest < ActionDispatch::IntegrationTest

  setup do
    @offer = Offer.create!(title: "Testkurs", type: "course", published: true)
    @event = @offer.events.create!(date_and_time: 1.week.from_now,
                                   max_no_of_participants: 10,
                                   published: true,
                                   registration_required: true)
  end

  # Turbo keeps asking for a turbo stream through a whole redirect chain, so
  # every request of the flow carries this header, not just the first one.
  TURBO_STREAM_HEADERS = {
    "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
  }.freeze

  def log_in
    post session_path, headers: TURBO_STREAM_HEADERS,
                       params: {login: {user_id: AlmaAuthenticationStub::VALID_USER_ID,
                                        password: AlmaAuthenticationStub::VALID_PASSWORD}}
  end

  test "the registration path is remembered as return target" do
    get new_frontend_event_registration_path(@event)

    assert_redirected_to new_session_path
    assert_equal new_frontend_event_registration_path(@event), session[:return_to]
  end

  test "the login sends the user back to the registration form" do
    get new_frontend_event_registration_path(@event)
    log_in

    assert_redirected_to new_frontend_event_registration_path(@event)
    follow_redirect!
    assert_response :success
  end

  # What the "Jetzt anmelden" link on the offer page actually does.
  test "the modal link leads to the registration form as a full page after the login" do
    get new_frontend_event_registration_path(@event, modal: 1), headers: TURBO_STREAM_HEADERS

    assert_redirected_to new_session_path
    # ?modal=1 must not be remembered: the placeholder it targets is gone by then.
    assert_equal new_frontend_event_registration_path(@event), session[:return_to]

    log_in
    assert_redirected_to new_frontend_event_registration_path(@event)

    get response.location, headers: TURBO_STREAM_HEADERS

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_select "form#event-registration-form"
  end

  # The offer page holds the #registration-modal placeholder, so there the
  # stream response is the right one.
  test "the modal link renders a turbo stream while logged in" do
    log_in
    follow_redirect!

    get new_frontend_event_registration_path(@event, modal: 1), headers: TURBO_STREAM_HEADERS

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "registration-modal", response.body
  end

  test "a direct visit without the modal param renders the full page" do
    log_in
    follow_redirect!

    get new_frontend_event_registration_path(@event)

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_select "form#event-registration-form"
  end

end
