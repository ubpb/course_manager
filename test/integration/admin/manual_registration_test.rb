require "test_helper"

# Staff enter participants without a library login by hand. They can send them
# the registration confirmation right away -- without any hint to an account
# these people do not have.
module Admin
  class ManualRegistrationTest < ActionDispatch::IntegrationTest

    include ActionMailer::TestHelper
    include MailerRecords
    include TurboStreamRequests

    setup do
      @offer = create_offer
      @event = create_event(date_and_time: 1.week.from_now)

      post admin_session_path, params: {login: {user_id: AlmaAuthenticationStub::VALID_USER_ID,
                                                password: AlmaAuthenticationStub::VALID_PASSWORD}}
    end

    def create_manual_registration(send_confirmation:, first_name: "Max")
      post admin_offer_event_registrations_path(@offer, @event),
           params: {registration: {first_name: first_name, last_name: "Mustermann", email: "max@example.com"},
                    send_confirmation: send_confirmation}
    end

    test "the new form offers the confirmation checkbox, checked" do
      get new_admin_offer_event_registration_path(@offer, @event)

      assert_response :success
      assert_select "form[action=?][data-turbo=false]", admin_offer_event_registrations_path(@offer, @event)
      assert_select "input[type=checkbox][name=send_confirmation][checked]"
    end

    test "the new form opens in a modal with the confirmation checkbox, checked" do
      get new_admin_offer_event_registration_path(@offer, @event), headers: TURBO_STREAM_HEADERS

      assert_select "turbo-stream[action=replace][target=registration-modal] template" do
        assert_select "input[type=checkbox][name=send_confirmation][checked]"
      end
    end

    test "a manual registration from the modal sends the confirmation when asked" do
      assert_enqueued_emails 1 do
        post admin_offer_event_registrations_path(@offer, @event),
             params: {registration: {first_name: "Max", last_name: "Mustermann", email: "max@example.com"},
                      send_confirmation: "1"},
             as: :turbo_stream
      end

      assert_select "turbo-stream[action=refresh]"
    end

    test "an invalid registration in the modal keeps the choice" do
      assert_no_enqueued_emails do
        post admin_offer_event_registrations_path(@offer, @event),
             params: {registration: {first_name: "", last_name: "Mustermann", email: "max@example.com"},
                      send_confirmation: "0"},
             as: :turbo_stream
      end

      assert_response :unprocessable_content
      assert_select "turbo-stream[action=replace][target=registration-form] template" do
        assert_select "input[type=checkbox][name=send_confirmation]"
        assert_select "input[type=checkbox][name=send_confirmation][checked]", count: 0
      end
    end

    # Staff add attendees after the event too, e.g. for a certificate. Thanking
    # them for registering to a date that has passed would only confuse.
    test "the checkbox starts unchecked for a past event" do
      @event.update!(date_and_time: 3.days.ago)

      get new_admin_offer_event_registration_path(@offer, @event)

      assert_select "input[type=checkbox][name=send_confirmation]"
      assert_select "input[type=checkbox][name=send_confirmation][checked]", count: 0
    end

    test "a manual registration sends the confirmation when asked" do
      assert_enqueued_emails 1 do
        create_manual_registration(send_confirmation: "1")
      end

      registration = @event.registrations.last
      body = ParticipantMailer.confirmation(registration).body.to_s

      assert_includes body, UNLINKED_CANCEL_INFO
      assert_not_includes body, "/account"
    end

    test "no confirmation without the checkbox" do
      assert_no_enqueued_emails do
        create_manual_registration(send_confirmation: "0")
      end

      assert_equal 1, @event.registrations.count
    end

    test "an invalid registration sends nothing and keeps the choice" do
      assert_no_enqueued_emails do
        create_manual_registration(send_confirmation: "0", first_name: "")
      end

      assert_response :unprocessable_entity
      assert_select "input[type=checkbox][name=send_confirmation]"
      assert_select "input[type=checkbox][name=send_confirmation][checked]", count: 0
    end

  end
end
