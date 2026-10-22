require "test_helper"

# The admin form and its live preview now edit the registration confirmation,
# so they have to render and round trip under the new attribute name.
class Admin::EventConfirmationMessageTest < ActionDispatch::IntegrationTest

  setup do
    @offer = Offer.create!(title: "Literaturrecherche", type: "course", published: true)
    @event = @offer.events.create!(date_and_time: 1.week.from_now,
                                   location: "Raum 1.2",
                                   max_no_of_participants: 10,
                                   registration_required: true,
                                   published: true)

    post admin_session_path, params: {login: {user_id: AlmaAuthenticationStub::VALID_USER_ID,
                                              password: AlmaAuthenticationStub::VALID_PASSWORD}}
  end

  test "the event form offers the confirmation message field" do
    get edit_admin_offer_event_path(@offer, @event)

    assert_response :success
    assert_select "textarea[name=?]", "event[participant_notes]"
  end

  # The text no longer goes into the confirmation only, and staff write it
  # differently when they know it is repeated just before the event.
  test "the hint tells staff everywhere the confirmation message appears" do
    get edit_admin_offer_event_path(@offer, @event)

    assert_includes response.body, "Anmeldebestätigung und die Erinnerungsmail"
    assert_includes response.body, "Detailseite"
  end

  test "the confirmation message is saved and shown in the preview" do
    patch admin_offer_event_path(@offer, @event),
          params: {event: {participant_notes: "Zugangsdaten folgen für ###NAME###."}}
    assert_equal "Zugangsdaten folgen für ###NAME###.", @event.reload.participant_notes

    get preview_confirmation_message_admin_offer_event_path(@offer, @event)

    assert_response :success
    assert_includes response.body, "vielen Dank für Ihre Anmeldung"
    assert_includes response.body, "Zugangsdaten folgen für Max Mustermann."
    # The preview shows the mail most participants get: the one for a
    # registration made from an account, pointing to its detail page.
    assert_includes response.body, "/account/anmeldungen/0"
  end

  test "the registration list offers the reminder actions without a stored text" do
    @event.registrations.create!(first_name: "Max", last_name: "Mustermann", email: "max@example.com")

    get admin_offer_event_registrations_path(@offer, @event)

    assert_response :success
    assert_select "option[value=?]", "send_reminder_messages"
    assert_select "option[value=?]", "force_send_reminder_messages"
  end

end
