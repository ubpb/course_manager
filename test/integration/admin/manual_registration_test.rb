require "test_helper"

# Staff enter participants without a library login by hand. They can send them
# the registration confirmation right away -- without any hint to an account
# these people do not have.
class Admin::ManualRegistrationTest < ActionDispatch::IntegrationTest

  include ActionMailer::TestHelper
  include MailerRecords

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
    assert_select "input[type=checkbox][name=send_confirmation][checked]"
  end

  test "a manual registration sends the confirmation when asked" do
    assert_enqueued_emails 1 do
      create_manual_registration(send_confirmation: "1")
    end

    registration = @event.registrations.last
    body = Frontend::Mailers::RegistrationsMailer.confirmation(registration).body.to_s

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
