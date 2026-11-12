require "test_helper"

# Registering for an event takes no login: a guest fills in the form and gets
# the confirmation by mail. The login stays on offer at the top of the form,
# for those who want the registration in their account.
module Frontend
  class GuestRegistrationTest < ActionDispatch::IntegrationTest

    include ActionMailer::TestHelper
    include MailerRecords
    include TurboStreamRequests

    setup do
      @offer = create_offer
      @event = create_event(date_and_time: 1.week.from_now)
    end

    def form_path
      new_frontend_event_registration_path(@event)
    end

    def register(**extra)
      post frontend_event_registrations_path(@event),
           params: {registration: {first_name: "Erika", last_name: "Mustermann",
                                   email: "erika@example.com", gdrp_consent: "1", **extra}}
    end

    test "the form opens without a login, empty, with the login box" do
      get form_path

      assert_response :success
      assert_predicate css_select("input[name='registration[first_name]']").first["value"], :blank?
      assert_select "a[href=?]", new_session_path(return_to: form_path), text: "Mit Bibliothekskonto einloggen"
      assert_select "input[type=submit][value=?]", "Verbindlich anmelden"
    end

    test "the modal opens without a login" do
      get new_frontend_event_registration_path(@event, modal: 1), headers: TURBO_STREAM_HEADERS

      assert_response :success
      assert_select "turbo-stream[action=replace][target=registration-modal] template" do
        assert_select "a[href=?]", new_session_path(return_to: form_path), text: "Mit Bibliothekskonto einloggen"
        assert_select "button[type=submit]", text: "Verbindlich anmelden"
      end
    end

    # Neither the ILS id nor the origin is taken from the params.
    test "a guest registers" do
      assert_enqueued_emails 2 do
        register(ils_primary_id: "99999", origin: "admin")
      end

      registration = @event.registrations.sole

      assert_predicate registration, :origin_guest?
      assert_nil registration.ils_primary_id
      assert_redirected_to frontend_offer_path(@offer)
      assert_equal "Anmeldung erfolgreich. Wir haben Ihnen eine Bestätigung per E-Mail gesendet.", flash[:notice]
    end

    test "the confirmation tells a guest to reply instead of pointing to an account" do
      perform_enqueued_jobs { register }

      confirmation = ActionMailer::Base.deliveries.find { it.to == ["erika@example.com"] }

      assert_includes confirmation.body.to_s, MailerRecords::UNLINKED_CANCEL_INFO
      assert_not_includes confirmation.body.to_s, "/account/"
    end

  end
end
