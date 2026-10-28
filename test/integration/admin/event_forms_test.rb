require "test_helper"

# The forms of an event: its data, which tell the participants about changes
# that matter to them, a copy to start the next date from, and the statistics
# and certificate, which exist at most once per event.
module Admin
  class EventFormsTest < ActionDispatch::IntegrationTest

    include AdminLogin
    include MailerRecords
    include ReportRecords

    setup do
      @offer = create_offer
      @event = create_event(date_and_time: 1.week.from_now.change(hour: 10))
      log_in_admin
    end

    def update_event(**attributes)
      patch admin_offer_event_path(@offer, @event), params: {event: attributes}
    end

    def recipients
      ActionMailer::Base.deliveries.flat_map(&:to)
    end

    test "a new event without a date shows the form again" do
      assert_no_difference -> { Event.count } do
        post admin_offer_events_path(@offer), params: {event: {date_and_time: "", max_no_of_participants: 10}}
      end

      assert_response :unprocessable_content
    end

    test "moving an upcoming event tells every participant" do
      create_registration(email: "max@example.com")
      create_registration(email: "erika@example.com")

      update_event(location: "Raum 2.1")

      assert_redirected_to edit_admin_offer_event_path(@offer, @event)
      assert_equal ["erika@example.com", "max@example.com"], recipients.sort
      assert_equal "Raum 2.1", @event.reload.location
    end

    test "a change that does not concern the participants sends nothing" do
      create_registration

      update_event(max_no_of_participants: 20)

      assert_empty recipients
      assert_equal 20, @event.reload.max_no_of_participants
    end

    test "a change to a past event sends nothing" do
      @event.update!(date_and_time: 2.days.ago)
      create_registration

      update_event(location: "Raum 2.1")

      assert_empty recipients
    end

    test "an anonymized participant gets no change notice" do
      create_registration(email: "max@example.com")
      create_registration.update_columns(Registration::ANONYMIZED_ATTRIBUTES)

      update_event(location: "Raum 2.1")

      assert_equal ["max@example.com"], recipients
    end

    test "a copy starts unpublished, empty and now" do
      travel_to Time.zone.parse("2026-10-28 09:41:27") do
        create_registration

        assert_difference -> { @offer.events.count }, 1 do
          get duplicate_admin_offer_event_path(@offer, @event)
        end
      end

      copy = @offer.events.order(:id).last

      assert_redirected_to edit_admin_offer_event_path(@offer, copy)
      assert_equal Time.zone.parse("2026-10-28 09:41"), copy.date_and_time
      assert_not copy.published
      assert_equal 0, copy.registrations_count
      assert_equal @event.location, copy.location
      assert_match "dupliziert", flash[:notice]
    end

    test "the statistics open as the form that fits" do
      get admin_offer_event_report_path(@offer, @event)

      assert_redirected_to new_admin_offer_event_report_path(@offer, @event)

      create_report
      get admin_offer_event_report_path(@offer, @event)

      assert_redirected_to edit_admin_offer_event_report_path(@offer, @event)

      get new_admin_offer_event_report_path(@offer, @event)

      assert_redirected_to edit_admin_offer_event_report_path(@offer, @event)
    end

    test "saved statistics download as a spreadsheet" do
      @event.update!(date_and_time: Time.zone.parse("2026-11-05 14:30"))
      create_report

      get admin_offer_event_report_path(@offer, @event, format: :xlsx)

      assert_response :success
      assert_equal 'attachment; filename="2026-11-05_14-30_literaturrecherche_report.xlsx"',
                   response.headers["Content-Disposition"]
    end

    test "incomplete statistics show the form again" do
      post admin_offer_event_report_path(@offer, @event), params: {report: {duration: ""}}

      assert_response :unprocessable_content
      assert_nil @event.reload.report

      create_report
      patch admin_offer_event_report_path(@offer, @event), params: {report: {duration: ""}}

      assert_response :unprocessable_content
      assert_equal 90, @event.reload.report.duration
    end

    test "the certificate opens as the form that fits" do
      get admin_offer_event_certification_path(@offer, @event)

      assert_redirected_to new_admin_offer_event_certification_path(@offer, @event)

      Certification.create!(event: @event, learning_results: "Katalogrecherche")
      get admin_offer_event_certification_path(@offer, @event)

      assert_redirected_to edit_admin_offer_event_certification_path(@offer, @event)

      get new_admin_offer_event_certification_path(@offer, @event)

      assert_redirected_to edit_admin_offer_event_certification_path(@offer, @event)
    end

    test "a certificate without learning results shows the form again" do
      post admin_offer_event_certification_path(@offer, @event), params: {certification: {learning_results: ""}}

      assert_response :unprocessable_content
      assert_nil @event.reload.certification

      Certification.create!(event: @event, learning_results: "Katalogrecherche")
      patch admin_offer_event_certification_path(@offer, @event), params: {certification: {learning_results: ""}}

      assert_response :unprocessable_content
      assert_equal "Katalogrecherche", @event.reload.certification.learning_results
    end

  end
end
