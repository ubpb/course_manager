require "test_helper"

# Before the registration form is shown or saved, the event has to take
# registrations at all, still be open, and the user must not be registered yet.
module Frontend
  class RegistrationChecksTest < ActionDispatch::IntegrationTest

    include ActionMailer::TestHelper

    setup do
      @offer = Offer.create!(title: "Literaturrecherche", type: "course", published: true)
      @event = @offer.events.create!(date_and_time: 1.week.from_now,
                                     max_no_of_participants: 10,
                                     registration_required: true,
                                     published: true)

      post session_path, params: {login: {user_id: AlmaAuthenticationStub::VALID_USER_ID,
                                          password: AlmaAuthenticationStub::VALID_PASSWORD}}
    end

    def register
      post frontend_event_registrations_path(@event),
           params: {registration: {first_name: "Erika", last_name: "Mustermann",
                                   email: "erika@example.com", gdrp_consent: "1"}}
    end

    def assert_turned_away_with(alert)
      assert_redirected_to frontend_offer_path(@offer)
      assert_equal alert, flash[:alert]
    end

    test "an open event shows the form and takes the registration" do
      get new_frontend_event_registration_path(@event)

      assert_response :success

      assert_difference -> { @event.registrations.count }, 1 do
        register
      end
    end

    test "the list of registrations leads to the form" do
      get frontend_event_registrations_path(@event)

      assert_redirected_to new_frontend_event_registration_path(@event)
    end

    test "a registration without consent shows the form again" do
      assert_no_difference -> { @event.registrations.count } do
        post frontend_event_registrations_path(@event),
             params: {registration: {first_name: "Erika", last_name: "Mustermann", email: "erika@example.com"}}
      end

      assert_response :unprocessable_content
      assert_select "form[action=?]", frontend_event_registrations_path(@event)
    end

    test "in the modal a registration without consent only replaces the form" do
      post frontend_event_registrations_path(@event, modal: 1),
           params: {registration: {first_name: "Erika", last_name: "Mustermann", email: "erika@example.com"}},
           as: :turbo_stream

      assert_response :unprocessable_content
      assert_select "turbo-stream[action=replace][target=registration-form]"
    end

    test "an event without registration turns the user away" do
      @event.update!(registration_required: false)

      get new_frontend_event_registration_path(@event)

      assert_turned_away_with "Anmeldung nicht erforderlich"
    end

    test "a full event turns the user away, also when posting directly" do
      @event.update!(max_no_of_participants: 1)
      @event.registrations.create!(first_name: "Max", last_name: "Muster", email: "max@example.com")

      assert_no_difference -> { @event.registrations.count } do
        register
      end
      assert_turned_away_with "Die Anmeldung ist geschlossen"
    end

    # Two requests at the same moment (a double click, two tabs) both pass the
    # checks; the unique index stops the second one, which must still end on
    # the offer page instead of an error.
    test "a registration losing the race to an identical one is turned away" do
      competing = lambda do |registration|
        Registration.insert_all!([registration.attributes.except("id").merge(
          "created_at" => Time.current, "updated_at" => Time.current
        )])
      end
      Registration.set_callback(:create, :before, competing)

      assert_no_enqueued_emails do
        register
      end
      assert_turned_away_with "Sie sind bereits für diesen Termin angemeldet."
    ensure
      Registration.skip_callback(:create, :before, competing)
    end

    test "a second registration of the same user is turned away" do
      register

      assert_no_difference -> { @event.registrations.count } do
        register
      end
      assert_turned_away_with "Sie sind bereits für diesen Termin angemeldet."
    end

  end
end
