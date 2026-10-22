require "test_helper"

# The registration confirmation carries the per-event text staff maintain in the
# admin, and the reminder repeats it: weeks may lie between the two mails.
class RegistrationMailsTest < ActionMailer::TestCase

  setup do
    @offer = Offer.create!(title: "Literaturrecherche", type: "course", published: true)
    @event = @offer.events.create!(date_and_time: Time.zone.parse("2026-10-15 10:00"),
                                   duration: 90,
                                   location: "Raum 1.2",
                                   max_no_of_participants: 10,
                                   registration_required: true,
                                   published: true)
    @registration = @event.registrations.create!(first_name: "Max",
                                                 last_name: "Mustermann",
                                                 email: "max@example.com")
  end

  def confirmation_body
    ParticipantMailer.confirmation(@registration).body.to_s
  end

  def reminder_body
    ParticipantMailer.reminder(@registration, skip_if_sent: false).body.to_s
  end

  test "the confirmation is sent without a custom text on the event" do
    body = confirmation_body

    assert_includes body, "vielen Dank für Ihre Anmeldung"
    assert_includes body, "das Schulungsteam der UB Paderborn"
  end

  test "the custom text is appended to the confirmation with placeholders expanded" do
    @event.update!(participant_notes: "###ANREDE###, der Termin am ###DATUM### findet in ###TREFFPUNKT### statt.")

    body = confirmation_body

    assert_includes body, "vielen Dank für Ihre Anmeldung"
    assert_includes body, "Hallo Max Mustermann, der Termin am 15.10.2026 findet in Raum 1.2 statt."
  end

  test "the reminder is sent from the static template even without a custom text" do
    body = reminder_body

    assert_includes body, "wir möchten Sie an Ihre Anmeldung"
    assert_includes body, "Literaturrecherche"
    assert_includes body, "Ort / Treffpunkt: \"Raum 1.2\"."
  end

  test "the reminder is skipped for a registration that already got one" do
    @registration.update!(reminder_message_sent_at: Time.zone.now)

    mail = ParticipantMailer.reminder(@registration)

    assert_equal "", mail.body.to_s
  end

  test "the custom text is part of the reminder" do
    @event.update!(participant_notes: "###ANREDE###, bitte Zotero installieren.")

    body = reminder_body

    assert_includes body, "Ort / Treffpunkt: \"Raum 1.2\".\n\nHallo Max Mustermann, bitte Zotero installieren.\n\n"
  end

  # Markdown is written to read well as plain text, so the mails carry it as is.
  test "the mails keep the Markdown of the notes as plain text" do
    @event.update!(participant_notes: "Bitte **pünktlich** sein.\n\n- Laptop")

    [confirmation_body, reminder_body].each do |body|
      assert_includes body, "Bitte **pünktlich** sein.\n\n- Laptop"
      assert_not_includes body, "<strong>"
    end
  end

  test "a reminder without custom text and place has no gap" do
    @event.update!(participant_notes: nil, location: nil)

    assert_not_includes reminder_body, "\n\n\n"
  end

end
