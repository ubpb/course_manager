require "test_helper"

# The four mails around a registration: participants get a confirmation and a
# cancellation receipt, the training team gets a notification for both.
class Frontend::RegistrationsMailerTest < ActionMailer::TestCase

  include MailerRecords

  TEAM = "schulung@ub.uni-paderborn.de".freeze

  setup do
    @offer = create_offer
    @event = create_event
    @registration = create_registration
  end

  test "the confirmation goes to the participant and answers to the team" do
    mail = Frontend::Mailers::RegistrationsMailer.confirmation(@registration)

    assert_equal ["max@example.com"], mail.to
    assert_equal [TEAM], mail.from
    assert_equal [TEAM], mail.reply_to
    assert_equal "[UB Paderborn] Ihre Schulungsanmeldung", mail.subject
  end

  test "the confirmation answers to the address kept on the event" do
    @event.update!(email_from: "auskunft@ub.uni-paderborn.de")

    mail = Frontend::Mailers::RegistrationsMailer.confirmation(@registration)

    assert_equal ["auskunft@ub.uni-paderborn.de"], mail.reply_to
    assert_equal [TEAM], mail.from
  end

  test "the confirmation repeats offer, date and start time" do
    body = Frontend::Mailers::RegistrationsMailer.confirmation(@registration).body.to_s

    assert_includes body, "Hallo Max Mustermann,"
    assert_includes body, "vielen Dank für Ihre Anmeldung zu unserer Schulungsveranstaltung \"Literaturrecherche\" am 15.10.2026"
    assert_includes body, "Die Veranstaltung beginnt um 10:00 Uhr."
    assert_includes body, "Ort / Treffpunkt: \"Raum 1.2\"."
    assert_includes body, "klicken beim Termin auf \"abmelden\": http://example.com/account"
    assert_includes body, "das Schulungsteam der UB Paderborn"
  end

  test "the notification goes to the team with the registration data" do
    mail = Frontend::Mailers::RegistrationsMailer.notification(@registration)

    assert_equal [TEAM], mail.to
    assert_equal "[SchulungsDB] Eine neue Anmeldung", mail.subject

    body = mail.body.to_s

    assert_includes body, "Hallo Schulungsteam!"
    assert_includes body, "Schulung: Literaturrecherche"
    assert_includes body, "Termin: 15.10.2026"
    assert_includes body, "Zeit: 10:00 Uhr"
    assert_includes body, "Nachname: Mustermann"
    assert_includes body, "Vorname: Max"
    assert_includes body, "E-Mail: max@example.com"
  end

  # The registration row is gone by the time these two are delivered, so name and
  # address travel as plain values.
  test "the cancellation confirmation greets the passed name" do
    mail = Frontend::Mailers::RegistrationsMailer.cancellation_confirmation(
      @event, full_name: "Erika Musterfrau", email: "erika@example.com"
    )

    assert_equal ["erika@example.com"], mail.to
    assert_equal [TEAM], mail.reply_to
    assert_equal "[UB Paderborn] Ihre Abmeldung von einer Schulung", mail.subject

    body = mail.body.to_s

    assert_includes body, "Hallo Erika Musterfrau,"
    assert_includes body, "hiermit bestätigen wir Ihre Abmeldung von unserer Schulungsveranstaltung \"Literaturrecherche\" am 15.10.2026."
    assert_includes body, "das Schulungsteam der UB Paderborn"
  end

  test "the cancellation confirmation answers to the address kept on the event" do
    @event.update!(email_from: "auskunft@ub.uni-paderborn.de")

    mail = Frontend::Mailers::RegistrationsMailer.cancellation_confirmation(
      @event, full_name: "Erika Musterfrau", email: "erika@example.com"
    )

    assert_equal ["auskunft@ub.uni-paderborn.de"], mail.reply_to
  end

  test "the cancellation notification tells the team who left" do
    mail = Frontend::Mailers::RegistrationsMailer.cancellation_notification(
      @event, full_name: "Erika Musterfrau", email: "erika@example.com"
    )

    assert_equal [TEAM], mail.to
    assert_equal "[SchulungsDB] Eine Anmeldung wurde storniert", mail.subject

    body = mail.body.to_s

    assert_includes body, "Eine Anmeldung für eine Schulung wurde storniert."
    assert_includes body, "Schulung: Literaturrecherche"
    assert_includes body, "Termin: 15.10.2026"
    assert_includes body, "Zeit: 10:00 Uhr"
    assert_includes body, "Name: Erika Musterfrau"
    assert_includes body, "E-Mail: erika@example.com"
  end

  test "each mail is actually deliverable" do
    assert_emails 1 do
      Frontend::Mailers::RegistrationsMailer.confirmation(@registration).deliver_now
    end
  end

end
