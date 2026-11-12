require "test_helper"

# The registration form offers the login with the library account, which fills
# in the form and puts the registration into the account. Logging in or out
# from there leads back to the form.
module Frontend
  class RegistrationLoginTest < ActionDispatch::IntegrationTest

    # Turbo keeps asking for a turbo stream through a whole redirect chain, so
    # every request of the flow carries these headers, not just the first one.
    include TurboStreamRequests

    setup do
      @offer = Offer.create!(title: "Testkurs", type: "course", published: true)
      @event = @offer.events.create!(date_and_time: 1.week.from_now,
                                     max_no_of_participants: 10,
                                     published: true,
                                     registration_required: true)
    end

    def form_path
      new_frontend_event_registration_path(@event)
    end

    # Like the login form, which carries the page that offered the login on.
    def log_in(return_to: nil)
      post session_path, headers: TURBO_STREAM_HEADERS,
                         params: {login: {user_id: AlmaAuthenticationStub::VALID_USER_ID,
                                          password: AlmaAuthenticationStub::VALID_PASSWORD},
                                  return_to: return_to}.compact
    end

    def first_name_value
      css_select("input[name='registration[first_name]']").first["value"]
    end

    # The modal is gone after the login, so the form comes back as a full page.
    test "the login from the form leads back to the form, prefilled" do
      get new_session_path(return_to: form_path), headers: TURBO_STREAM_HEADERS
      log_in(return_to: form_path)

      assert_redirected_to form_path

      get response.location, headers: TURBO_STREAM_HEADERS

      assert_response :success
      assert_equal "text/html", response.media_type
      assert_equal "Erika", first_name_value
    end

    test "logged in, the form names the user and offers the logout back to the form" do
      log_in
      get form_path

      assert_select ".callout", text: /Eingeloggt als Erika Mustermann/
      assert_select "a[href=?]", logout_path(return_to: form_path), text: "Ausloggen"
      assert_select "a", text: "Mit Bibliothekskonto einloggen", count: 0
    end

    test "the logout from the form leads back to the form as a guest" do
      log_in
      get logout_path(return_to: form_path)

      assert_redirected_to form_path
      follow_redirect!

      assert_select "a[href=?]", new_session_path(return_to: form_path), text: "Mit Bibliothekskonto einloggen"
      assert_predicate first_name_value, :blank?
    end

    # Neither the ILS id nor the origin is taken from the params.
    test "a logged-in user registers with the account" do
      log_in
      post frontend_event_registrations_path(@event),
           params: {registration: {first_name: "Erika", last_name: "Mustermann", email: "erika@example.com",
                                   gdrp_consent: "1", ils_primary_id: "99999", origin: "guest"}}

      registration = @event.registrations.sole

      assert_predicate registration, :origin_account?
      assert_equal AlmaAuthenticationStub::VALID_USER_ID, registration.ils_primary_id
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

      get form_path

      assert_response :success
      assert_equal "text/html", response.media_type
      assert_select "form#event-registration-form"
    end

  end
end
