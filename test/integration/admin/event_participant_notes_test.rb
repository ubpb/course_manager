require "test_helper"

# The notes for participants are part of the general event data. Apart from
# them, staff can preview the confirmation and the reminder mail as they would
# go out with what the form currently holds -- without saving anything.
class Admin::EventParticipantNotesTest < ActionDispatch::IntegrationTest

  include ActionMailer::TestHelper

  TURBO_STREAM_HEADERS = {
    "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
  }.freeze

  setup do
    @offer = Offer.create!(title: "Literaturrecherche", type: "course", published: true)
    @event = @offer.events.create!(date_and_time: Time.zone.parse("2026-11-05 14:00"),
                                   location: "Raum 1.2",
                                   max_no_of_participants: 10,
                                   registration_required: true,
                                   published: true)

    post admin_session_path, params: {login: {user_id: AlmaAuthenticationStub::VALID_USER_ID,
                                              password: AlmaAuthenticationStub::VALID_PASSWORD}}
  end

  def preview(kind, **event_attributes)
    post public_send(:"preview_#{kind}_admin_offer_events_path", @offer),
         params: {event: {date_and_time: "2026-11-05T14:00", location: "Raum 1.2"}.merge(event_attributes)},
         headers: TURBO_STREAM_HEADERS
  end

  test "the notes are part of the general event data" do
    get edit_admin_offer_event_path(@offer, @event)

    assert_response :success
    notes = response.body.index('name="event[participant_notes]"')
    assert notes, "no participant notes field"
    assert notes < response.body.index("Administrative Angaben"), "the notes field is not among the general data"
  end

  # The text is not only part of the confirmation, and staff write it
  # differently when they know it is repeated just before the event.
  test "the hint tells staff everywhere the notes appear" do
    get edit_admin_offer_event_path(@offer, @event)

    assert_includes response.body, "Hinweise für Teilnehmende"
    assert_includes response.body, "Anmeldebestätigung und die Erinnerungsmail"
    assert_includes response.body, "Detailseite"
    assert_includes response.body, "Markdown"
  end

  test "the notes are saved" do
    patch admin_offer_event_path(@offer, @event),
          params: {event: {participant_notes: "Zugangsdaten folgen für ###NAME###."}}

    assert_equal "Zugangsdaten folgen für ###NAME###.", @event.reload.participant_notes
  end

  test "the edit and the new form offer a preview of both mails" do
    [edit_admin_offer_event_path(@offer, @event), new_admin_offer_event_path(@offer)].each do |path|
      get path

      assert_select "#mail-preview-modal"
      assert_select "button[type=button][data-action='mail-preview#open'][data-mail-preview-url-param=?]",
                    preview_confirmation_admin_offer_events_path(@offer), text: /Anmeldebestätigung/
      assert_select "button[type=button][data-action='mail-preview#open'][data-mail-preview-url-param=?]",
                    preview_reminder_admin_offer_events_path(@offer), text: /Erinnerungsmail/
    end
  end

  test "the confirmation preview shows the mail with the notes from the form" do
    preview(:confirmation, participant_notes: "Zugangsdaten folgen für ###NAME###.")

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, '<turbo-stream action="replace" target="mail-preview-modal">'
    assert_includes response.body, "[UB Paderborn] Anmeldebestätigung: Literaturrecherche (05.11.2026)"
    assert_includes response.body, "vielen Dank für Ihre Anmeldung"
    assert_includes response.body, "05.11.2026"
    assert_includes response.body, "Zugangsdaten folgen für Max Mustermann."
    # The mail most participants get: for a registration made from an account,
    # pointing to its detail page.
    assert_includes response.body, "/account/anmeldungen/0"
  end

  test "the reminder preview shows the mail with the notes from the form" do
    preview(:reminder, participant_notes: "Bitte ###NAME### mitbringen.")

    assert_response :success
    assert_includes response.body, "[UB Paderborn] Erinnerung: Literaturrecherche (05.11.2026)"
    assert_includes response.body, "wir möchten Sie an Ihre Anmeldung"
    assert_includes response.body, "Bitte Max Mustermann mitbringen."
  end

  # A preview must not act like saving: no event is created or changed, and
  # nobody is told about a moved date.
  test "a preview saves nothing and mails nobody" do
    @event.registrations.create!(first_name: "Max", last_name: "Mustermann", email: "max@example.com")

    assert_no_emails do
      assert_no_difference "Event.count" do
        preview(:confirmation, date_and_time: "2026-12-01T09:00", participant_notes: "Neu")
      end
    end

    @event.reload
    assert_equal Time.zone.parse("2026-11-05 14:00"), @event.date_and_time
    assert_nil @event.participant_notes
  end

  test "without a date the preview asks for one" do
    preview(:reminder, date_and_time: "")

    assert_response :success
    assert_includes response.body, "Bitte geben Sie zuerst Datum und Uhrzeit an"
  end

  test "the registration list offers the reminder actions without stored notes" do
    @event.registrations.create!(first_name: "Max", last_name: "Mustermann", email: "max@example.com")

    get admin_offer_event_registrations_path(@offer, @event)

    assert_response :success
    assert_select "option[value=?]", "send_reminder_messages"
    assert_select "option[value=?]", "force_send_reminder_messages"
  end

end
