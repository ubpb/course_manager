require "test_helper"

# What staff do with the participants of an event: edit and remove them, hand
# out certificates, send reminders and write to them -- one at a time from the
# row menu or for a selection through the bulk actions.
module Admin
  class RegistrationActionsTest < ActionDispatch::IntegrationTest

    include ActionMailer::TestHelper
    include AdminLogin
    include MailerRecords
    include TurboStreamRequests

    setup do
      @offer = create_offer
      @event = create_event(date_and_time: 2.days.ago)
      @registration = create_registration
      log_in_admin
    end

    def certify
      Certification.create!(event: @event, learning_results: "Katalogrecherche", signature: "Max Muster")
      @event.reload
    end

    def bulk_process(action, registrations = [@registration], **)
      patch bulk_process_admin_offer_event_registrations_path(@offer, @event),
            params: {bulk_process_action: action, bulk_process_ids: registrations.map(&:id)}, **
    end

    test "the participant list downloads as a spreadsheet named after date, time and offer" do
      @event.update!(date_and_time: Time.zone.parse("2026-11-05 14:30"))

      get admin_offer_event_registrations_path(@offer, @event, format: :xlsx)

      assert_response :success
      assert_equal 'attachment; filename="2026-11-05_14-30_literaturrecherche.xlsx"',
                   response.headers["Content-Disposition"]
    end

    test "the bulk actions offer the certificate only once the event has a certification" do
      get admin_offer_event_registrations_path(@offer, @event)

      assert_select "select#bulk_process_action option[value=send_certificates]", count: 0
      assert_select "select#bulk_process_action option[value=send_message]"

      certify
      get admin_offer_event_registrations_path(@offer, @event)

      assert_select "select#bulk_process_action option[value=send_certificates]"
    end

    test "without participants there are no bulk actions" do
      @registration.destroy

      get admin_offer_event_registrations_path(@offer, @event)

      assert_response :success
      assert_select "select#bulk_process_action", count: 0
    end

    test "the participant list opens new participants and edits in a modal" do
      get admin_offer_event_registrations_path(@offer, @event)

      assert_select "#registration-modal"
      assert_select "a[href=?][data-turbo-stream]", new_admin_offer_event_registration_path(@offer, @event)
      assert_select "a[href=?][data-turbo-stream]",
                    edit_admin_offer_event_registration_path(@offer, @event, @registration)
      assert_select "head meta[name=turbo-refresh-scroll][content=preserve]"
    end

    test "a participant opens in a modal that a click beside it does not close" do
      get edit_admin_offer_event_registration_path(@offer, @event, @registration), headers: TURBO_STREAM_HEADERS

      assert_select "turbo-stream[action=replace][target=registration-modal] template" do
        assert_select ".modal[data-bs-backdrop=static] .modal-dialog.modal-lg #registration-form"
        assert_select "input[name='registration[first_name]'][autofocus]"
        assert_select "a[href=?][data-turbo-method=delete]",
                      admin_offer_event_registration_path(@offer, @event, @registration), text: "Löschen"
        assert_select "input[name=send_confirmation]", count: 0
      end
    end

    test "a participant is edited on a page of its own, submitted without Turbo" do
      get edit_admin_offer_event_registration_path(@offer, @event, @registration)

      assert_select "form[action=?][data-turbo=false]",
                    admin_offer_event_registration_path(@offer, @event, @registration)
    end

    test "a participant saved in the modal refreshes the list" do
      patch admin_offer_event_registration_path(@offer, @event, @registration),
            params: {registration: {first_name: "Moritz"}}, as: :turbo_stream

      assert_select "turbo-stream[action=refresh]"
      assert_equal "Erfolgreich gespeichert.", flash[:notice]
      assert_equal "Moritz", @registration.reload.first_name
    end

    test "an invalid participant in the modal shows the errors there" do
      patch admin_offer_event_registration_path(@offer, @event, @registration),
            params: {registration: {email: "keine-adresse"}}, as: :turbo_stream

      assert_response :unprocessable_content
      assert_select "turbo-stream[action=replace][target=registration-form]"
      assert_select "turbo-stream[target=registration-modal]", count: 0
    end

    # From the modal, Turbo renders the redirect to the list that is open as a
    # refresh of it; from the participant's page it leads to the list.
    test "removing a participant from the modal leads back to the list" do
      delete admin_offer_event_registration_path(@offer, @event, @registration), as: :turbo_stream

      assert_redirected_to admin_offer_event_registrations_path(@offer, @event)
      assert_not Registration.exists?(@registration.id)
    end

    test "saving a participant leads back to the list" do
      patch admin_offer_event_registration_path(@offer, @event, @registration),
            params: {registration: {first_name: "Moritz", internal_notes: "Kommt später"}}

      assert_redirected_to admin_offer_event_registrations_path(@offer, @event)
      assert_equal "Erfolgreich gespeichert.", flash[:notice]
      assert_equal "Moritz", @registration.reload.first_name
      assert_equal "Kommt später", @registration.internal_notes
    end

    test "an invalid participant shows the form again" do
      patch admin_offer_event_registration_path(@offer, @event, @registration),
            params: {registration: {email: "keine-adresse"}}

      assert_response :unprocessable_content
      assert_equal "max@example.com", @registration.reload.email
    end

    test "removing a participant leads back to the list" do
      delete admin_offer_event_registration_path(@offer, @event, @registration)

      assert_redirected_to admin_offer_event_registrations_path(@offer, @event)
      assert_not Registration.exists?(@registration.id)
    end

    test "the certificate downloads as a PDF and is kept for the check" do
      certify

      assert_difference -> { @registration.certificates.count }, 1 do
        get download_certificate_admin_offer_event_registration_path(@offer, @event, @registration)
      end

      assert_response :success
      assert_equal "application/pdf", response.media_type
      assert_includes response.headers["Content-Disposition"], Certificate.filename(@registration)
      assert_equal Digest::SHA256.hexdigest(response.body), @registration.certificates.last.digest
    end

    test "without a certification there is no certificate to download" do
      assert_no_difference -> { Certificate.count } do
        get download_certificate_admin_offer_event_registration_path(@offer, @event, @registration)
      end

      assert_response :success
      assert_empty response.body
    end

    test "sending a certificate mails it and notes when" do
      certify

      assert_enqueued_emails 1 do
        patch send_certificate_admin_offer_event_registration_path(@offer, @event, @registration)
      end

      assert_redirected_to admin_offer_event_registrations_path(@offer, @event)
      assert_equal "Zertifikat wurde versendet", flash[:success]
      assert_not_nil @registration.reload.certificate_sent_at
    end

    test "sending a reminder from the row menu sends it again" do
      @registration.update!(reminder_message_sent_at: 1.day.ago)

      patch send_reminder_message_admin_offer_event_registration_path(@offer, @event, @registration)
      perform_enqueued_jobs

      assert_redirected_to admin_offer_event_registrations_path(@offer, @event)
      assert_equal ["max@example.com"], ActionMailer::Base.deliveries.map(&:to).flatten
      assert_in_delta Time.zone.now, @registration.reload.reminder_message_sent_at, 1.minute
    end

    test "the bulk certificate mail goes to the selected participants only" do
      certify
      other = create_registration(first_name: "Erika", email: "erika@example.com")

      assert_enqueued_emails 1 do
        bulk_process("send_certificates")
      end

      assert_redirected_to admin_offer_event_registrations_path(@offer, @event)
      assert_not_nil @registration.reload.certificate_sent_at
      assert_nil other.reload.certificate_sent_at
    end

    # The job of the mail runs after the request, as in production -- by then
    # the participant is marked as reminded.
    test "the bulk reminder leaves out participants who already have one" do
      reminded = create_registration(first_name: "Erika", email: "erika@example.com",
                                     reminder_message_sent_at: 1.day.ago)

      bulk_process("send_reminder_messages", [@registration, reminded])
      perform_enqueued_jobs

      assert_redirected_to admin_offer_event_registrations_path(@offer, @event)
      assert_equal ["max@example.com"], ActionMailer::Base.deliveries.map(&:to).flatten
    end

    test "the forced bulk reminder goes to everyone selected" do
      reminded = create_registration(first_name: "Erika", email: "erika@example.com",
                                     reminder_message_sent_at: 1.day.ago)

      bulk_process("force_send_reminder_messages", [@registration, reminded])
      perform_enqueued_jobs

      assert_equal ["erika@example.com", "max@example.com"], ActionMailer::Base.deliveries.map(&:to).flatten.sort
    end

    test "an unknown bulk action changes nothing" do
      assert_no_enqueued_emails do
        bulk_process("unknown")
      end

      assert_redirected_to admin_offer_event_registrations_path(@offer, @event)
    end

    test "writing a message opens the message dialog for the selection" do
      bulk_process("send_message", as: :turbo_stream)

      assert_response :success
      assert_equal "text/vnd.turbo-stream.html", response.media_type
      assert_select "turbo-stream[action=replace][target=bulk-action-form]"
      assert_includes response.body, %(value="#{@registration.id}")
    end

    test "a message goes to every selected participant" do
      other = create_registration(first_name: "Erika", email: "erika@example.com")

      post send_message_admin_offer_event_registrations_path(@offer, @event),
           params: {registration_ids: [@registration.id, other.id],
                    message: {subject: "Raumänderung", body: "Raum 2.1"}}

      assert_redirected_to admin_offer_event_registrations_path(@offer, @event)
      assert_equal "Nachricht gesendet", flash[:success]
      assert_equal ["erika@example.com", "max@example.com"], ActionMailer::Base.deliveries.map(&:to).flatten.sort
      assert_equal ["[UB Paderborn] Raumänderung"], ActionMailer::Base.deliveries.map(&:subject).uniq
    end

    test "a message without a subject only replaces the form in the open dialog" do
      post send_message_admin_offer_event_registrations_path(@offer, @event),
           params: {registration_ids: [@registration.id], message: {subject: "", body: "Raum 2.1"}},
           as: :turbo_stream

      assert_empty ActionMailer::Base.deliveries
      assert_select "turbo-stream[action=replace][target=bulk-action-message-form]"
    end

  end
end
