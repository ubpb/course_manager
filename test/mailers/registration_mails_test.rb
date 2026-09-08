require "test_helper"

# The registration confirmation carries the per-event text staff maintain in the
# admin, the reminder is a fixed template. Both used to be the other way round.
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
    Frontend::Mailers::RegistrationsMailer.confirmation(@registration).body.to_s
  end

  def reminder_body
    Admin::Mailers::EventsMailer.reminder_message(@registration, skip_if_sent: false).body.to_s
  end

  test "the confirmation is sent without a custom text on the event" do
    body = confirmation_body

    assert_includes body, "vielen Dank für Ihre Anmeldung"
    assert_includes body, "das Schulungsteam der UB Paderborn"
  end

  test "the custom text is appended to the confirmation with placeholders expanded" do
    @event.update!(confirmation_message: "###ANREDE###, der Termin am ###DATUM### findet in ###TREFFPUNKT### statt.")

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

    mail = Admin::Mailers::EventsMailer.reminder_message(@registration)

    assert_equal "", mail.body.to_s
  end

end
