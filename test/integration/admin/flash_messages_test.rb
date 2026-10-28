require "test_helper"

# The admin shows its flash messages as toasts at the top right. A form keeps
# the messages that belong to it, and the front end keeps its alerts.
module Admin
  class FlashMessagesTest < ActionDispatch::IntegrationTest

    include AdminLogin
    include MailerRecords

    test "a success message shows as a toast that hides by itself" do
      log_in_admin
      offer = create_offer

      patch bulk_process_admin_offers_path, params: {bulk_process_action: "archive", bulk_process_ids: [offer.id]}
      follow_redirect!

      assert_select "#admin-toasts .toast-container .toast.show[role=status][data-controller=toast]" \
                    "[data-bs-autohide=true][data-bs-delay='5000']", text: /Angebot\(e\) wurde archiviert/
      assert_select "#admin-toasts .toast .btn-close[data-bs-dismiss=toast]"
      assert_select "main .alert", count: 0
    end

    test "a warning shows as a toast that stays" do
      log_in_admin

      patch bulk_process_admin_events_path, params: {bulk_process_action: "move_to_offer"}
      follow_redirect!

      assert_select "#admin-toasts .toast[role=alert][data-bs-autohide=false]",
                    text: /Bitte mindestens einen Termin auswählen/
    end

    test "the choice of a course keeps its message in its card" do
      log_in_admin

      get new_admin_event_path(offer_id: 0)

      assert_select ".card .alert", text: /Bitte ein Angebot auswählen/
      assert_select "#admin-toasts .toast", count: 0
    end

    test "the login keeps its message in its card" do
      post admin_session_path, params: {login: {user_id: AlmaAuthenticationStub::VALID_USER_ID, password: "falsch"}}

      assert_response :unprocessable_content
      assert_select ".card .alert", text: /Fehler bei der Anmeldung/
      assert_select "#admin-toasts .toast", count: 0
    end

    test "the front end keeps its alerts in the page" do
      post frontend_cert_checks_path
      follow_redirect!

      assert_select ".alert.alert-danger", text: /Bitte wählen Sie eine Datei aus/
      assert_select "#admin-toasts", count: 0
    end

  end
end
