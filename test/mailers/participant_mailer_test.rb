require "test_helper"

# Every mail to a participant: confirmation and cancellation receipt, the
# reminder and the change notice, a message from staff and the certificate.
class ParticipantMailerTest < ActionMailer::TestCase

  include MailerRecords

  TEAM = "schulung@ub.uni-paderborn.de".freeze
  CERTIFICATE_FILENAME = "Teilnahmebescheinigung.pdf".freeze

  setup do
    @offer = create_offer
    @event = create_event
    @registration = create_registration
  end

  def reminder(**)
    ParticipantMailer.reminder(@registration, **)
  end

  def room_change_message
    Message.new(subject: "Raumänderung", body: "Wir treffen uns in Raum 9.")
  end

  def certificate_mail
    ParticipantMailer.certificate(@registration, "%PDF-1.7 fake", CERTIFICATE_FILENAME)
  end

  def certify!
    Certification.create!(event: @event, learning_results: "Katalogrecherche", signature: "Max Muster")
    @registration.reload
  end

  test "the confirmation goes to the participant and answers to the team" do
    mail = ParticipantMailer.confirmation(@registration)

    assert_equal ["max@example.com"], mail.to
    assert_equal [TEAM], mail.from
    assert_equal [TEAM], mail.reply_to
    assert_equal "[UB Paderborn] Anmeldebestätigung: Literaturrecherche (15.10.2026)", mail.subject
  end

  test "the confirmation answers to the address kept on the event" do
    @event.update!(email_from: "auskunft@ub.uni-paderborn.de")

    mail = ParticipantMailer.confirmation(@registration)

    assert_equal ["auskunft@ub.uni-paderborn.de"], mail.reply_to
    assert_equal [TEAM], mail.from
  end

  test "the confirmation repeats offer, date and start time" do
    body = ParticipantMailer.confirmation(@registration).body.to_s

    assert_includes body, "Hallo Max Mustermann,"
    assert_includes body,
                    "vielen Dank für Ihre Anmeldung zu unserer Schulungsveranstaltung \"Literaturrecherche\" am 15.10.2026"
    assert_includes body, "Die Veranstaltung beginnt um 10:00 Uhr."
    assert_includes body, "Ort / Treffpunkt: \"Raum 1.2\"."
    assert_includes body, UNLINKED_CANCEL_INFO
    assert_not_includes body, "/account"
    assert_includes body, "das Schulungsteam der UB Paderborn"
  end

  test "a linked confirmation points to the detail page" do
    registration = create_registration(ils_primary_id: "12345", email: "erika@example.com")

    body = ParticipantMailer.confirmation(registration).body.to_s

    assert_includes body, linked_cancel_info(registration)
    assert_not_includes body, UNLINKED_CANCEL_INFO
    assert_not_includes body, "\n\n\n"
  end

  # The registration row is gone by the time these two are delivered, so name and
  # address travel as plain values.
  test "the cancellation confirmation greets the passed name" do
    mail = ParticipantMailer.cancellation_confirmation(
      @event, full_name: "Erika Musterfrau", email: "erika@example.com"
    )

    assert_equal ["erika@example.com"], mail.to
    assert_equal [TEAM], mail.reply_to
    assert_equal "[UB Paderborn] Abmeldebestätigung: Literaturrecherche (15.10.2026)", mail.subject

    body = mail.body.to_s

    assert_includes body, "Hallo Erika Musterfrau,"
    assert_includes body,
                    "hiermit bestätigen wir Ihre Abmeldung von unserer Schulungsveranstaltung \"Literaturrecherche\" am 15.10.2026."
    assert_includes body, "das Schulungsteam der UB Paderborn"
  end

  test "the cancellation confirmation answers to the address kept on the event" do
    @event.update!(email_from: "auskunft@ub.uni-paderborn.de")

    mail = ParticipantMailer.cancellation_confirmation(
      @event, full_name: "Erika Musterfrau", email: "erika@example.com"
    )

    assert_equal ["auskunft@ub.uni-paderborn.de"], mail.reply_to
  end

  test "each mail is actually deliverable" do
    assert_emails 1 do
      ParticipantMailer.confirmation(@registration).deliver_now
    end
  end

  test "the reminder goes to the participant with date, time and place" do
    mail = reminder(skip_if_sent: false)

    assert_equal ["max@example.com"], mail.to
    assert_equal [TEAM], mail.from
    assert_equal [TEAM], mail.reply_to
    assert_equal "[UB Paderborn] Erinnerung: Literaturrecherche (15.10.2026)", mail.subject

    body = mail.body.to_s

    assert_includes body, "Hallo Max Mustermann,"
    assert_includes body,
                    "wir möchten Sie an Ihre Anmeldung zu unserer Schulungsveranstaltung \"Literaturrecherche\" erinnern."
    assert_includes body, "Termin: 15.10.2026"
    assert_includes body, "Uhrzeit: 10:00 Uhr"
    assert_includes body, "Ort / Treffpunkt: \"Raum 1.2\"."
    assert_includes body, UNLINKED_CANCEL_INFO
    assert_not_includes body, "/account"
    assert_includes body, "das Schulungsteam der UB Paderborn"
  end

  test "a linked reminder points to the detail page" do
    @registration.update!(ils_primary_id: "12345")

    body = reminder(skip_if_sent: false).body.to_s

    assert_includes body, linked_cancel_info(@registration)
    assert_not_includes body, UNLINKED_CANCEL_INFO
    assert_not_includes body, "\n\n\n"
  end

  test "the reminder answers to the address kept on the event" do
    @event.update!(email_from: "auskunft@ub.uni-paderborn.de")

    assert_equal ["auskunft@ub.uni-paderborn.de"], reminder(skip_if_sent: false).reply_to
  end

  test "a participant who already got a reminder is skipped by default" do
    @registration.update!(reminder_message_sent_at: 1.hour.ago)

    assert_no_emails do
      reminder.deliver_now
    end
  end

  test "staff can resend a reminder that was already sent" do
    @registration.update!(reminder_message_sent_at: 1.hour.ago)

    assert_emails 1 do
      reminder(skip_if_sent: false).deliver_now
    end
  end

  test "an anonymized registration is never reminded" do
    @registration.update_columns(first_name: "Gelöscht", last_name: "Gelöscht", email: "Gelöscht")

    assert_no_emails do
      reminder(skip_if_sent: false).deliver_now
    end
  end

  # The change notice is built from the unsaved changes on the event, so the
  # controller has to hand over a dirty record.
  test "an unchanged event notifies nobody" do
    assert_no_emails do
      ParticipantMailer.change_notice(@event, @registration).deliver_now
    end
  end

  test "a moved date is reported with the old and the new value" do
    @event.date_and_time = Time.zone.parse("2026-11-01 14:00")

    mail = ParticipantMailer.change_notice(@event, @registration)

    assert_equal ["max@example.com"], mail.to
    assert_equal [TEAM], mail.reply_to
    # The subject names the new date, the one that counts from now on.
    assert_equal "[UB Paderborn] Terminänderung: Literaturrecherche (01.11.2026)", mail.subject

    body = mail.body.to_s

    assert_includes body, "Hallo Max Mustermann,"
    assert_includes body, "Datum/Uhrzeit"
    assert_includes body, "Bisher: 15.10.2026, 10:00 Uhr"
    assert_includes body, "NEU: 01.11.2026, 14:00 Uhr"
    assert_not_includes body, "Treffpunkt"
    # Only a moved date is worth an early cancellation.
    assert_includes body, UNLINKED_CANCEL_INFO
  end

  test "a moved meeting point is reported without the cancel hint" do
    @event.location = "Raum 9"

    body = ParticipantMailer.change_notice(@event, @registration).body.to_s

    assert_includes body, "Treffpunkt"
    assert_includes body, "Bisher: Raum 1.2"
    assert_includes body, "NEU: Raum 9"
    assert_not_includes body, "Datum/Uhrzeit"
    assert_not_includes body, "nicht wahrnehmen"
  end

  test "a new access link is reported with the old and the new value" do
    @event.update!(online: true, online_url: "https://meet.example.com/abc", location: nil)
    @event.online_url = "https://meet.example.com/xyz"

    mail = ParticipantMailer.change_notice(@event, @registration)

    assert_equal ["max@example.com"], mail.to
    assert_equal "[UB Paderborn] Terminänderung: Literaturrecherche (15.10.2026)", mail.subject

    body = mail.body.to_s

    assert_includes body, "Zugangslink"
    assert_includes body, "Bisher: https://meet.example.com/abc"
    assert_includes body, "NEU: https://meet.example.com/xyz"
    assert_not_includes body, "Datum/Uhrzeit"
    assert_not_includes body, "Treffpunkt"
  end

  # An event announced without a link yet gets one later, so the old value is
  # regularly empty and must not print as a bare "Bisher:".
  test "a first access link is reported against a named placeholder" do
    @event.update!(online: true, online_url: nil, location: nil)
    @event.online_url = "https://meet.example.com/abc"

    body = ParticipantMailer.change_notice(@event, @registration).body.to_s

    assert_includes body, "Bisher: nicht angegeben"
    assert_includes body, "NEU: https://meet.example.com/abc"
  end

  test "a removed meeting point is reported against the same placeholder" do
    @event.location = nil

    body = ParticipantMailer.change_notice(@event, @registration).body.to_s

    assert_includes body, "Bisher: Raum 1.2"
    assert_includes body, "NEU: nicht angegeben"
  end

  test "date and meeting point moving together are both reported" do
    @event.assign_attributes(date_and_time: Time.zone.parse("2026-11-01 14:00"), location: "Raum 9")

    body = ParticipantMailer.change_notice(@event, @registration).body.to_s

    assert_includes body, "Bisher: 15.10.2026, 10:00 Uhr"
    assert_includes body, "NEU: 01.11.2026, 14:00 Uhr"
    assert_includes body, "Bisher: Raum 1.2"
    assert_includes body, "NEU: Raum 9"
  end

  test "every reported change gets its own block, separated by a single blank line" do
    @event.assign_attributes(date_and_time: Time.zone.parse("2026-11-01 14:00"), location: "Raum 9")

    body = ParticipantMailer.change_notice(@event, @registration).body.to_s

    assert_includes body, "Es gab folgende Änderungen:\n\nDatum/Uhrzeit"
    assert_includes body, "rechtzeitig mitzuteilen.\n\nTreffpunkt"
    assert_includes body, "NEU: Raum 9\n\nSollten Sie Fragen haben"
    assert_not_includes body, "\n\n\n"
  end

  test "a moved date and a switched form are both reported" do
    @event.assign_attributes(date_and_time: Time.zone.parse("2026-11-01 14:00"), online: true)

    body = ParticipantMailer.change_notice(@event, @registration).body.to_s

    assert_includes body, "NEU: 01.11.2026, 14:00 Uhr"
    assert_includes body, "rechtzeitig mitzuteilen.\n\nVeranstaltungsform"
    assert_includes body, "NEU: online"
    assert_not_includes body, "\n\n\n"
  end

  # A switched form changes where the participant has to show up, so the block
  # states the new arrangement instead of leaving it to a second block.
  test "switching to online is reported together with the access link" do
    @event.assign_attributes(online: true, online_url: "https://meet.example.com/abc")

    body = ParticipantMailer.change_notice(@event, @registration).body.to_s

    assert_includes body, "Veranstaltungsform\n------------------\nBisher: vor Ort\nNEU: online\n"
    assert_includes body, "Die Veranstaltung findet online statt. Zugangslink: https://meet.example.com/abc"
    assert_not_includes body, "Zugangslink\n-----------"
    assert_not_includes body, "Treffpunkt"
  end

  test "switching to online without a link points to the separate mail" do
    @event.online = true

    body = ParticipantMailer.change_notice(@event, @registration).body.to_s

    assert_includes body, "NEU: online"
    assert_includes body, "Zugangsdaten erhalten Sie vor der Veranstaltung in einer separaten E-Mail."
    assert_not_includes body, "Zugangslink"
  end

  test "switching back on site names the meeting point again" do
    @event.update!(online: true, online_url: "https://meet.example.com/abc")
    @event.online = false

    body = ParticipantMailer.change_notice(@event, @registration).body.to_s

    assert_includes body, "Veranstaltungsform\n------------------\nBisher: online\nNEU: vor Ort\n"
    assert_includes body, "Ort / Treffpunkt: \"Raum 1.2\"."
    assert_not_includes body, "https://meet.example.com/abc"
  end

  # The two place attributes are only worth a mail for the form the event is
  # actually held in.
  test "a link change on an on site event notifies nobody" do
    @event.online_url = "https://meet.example.com/abc"

    assert_no_emails do
      ParticipantMailer.change_notice(@event, @registration).deliver_now
    end
  end

  test "a meeting point change on an online event notifies nobody" do
    @event.update!(online: true, online_url: "https://meet.example.com/abc")
    @event.location = "Raum 9"

    assert_no_emails do
      ParticipantMailer.change_notice(@event, @registration).deliver_now
    end
  end

  # Only date and meeting point are reported, so any other edit would produce a
  # notice with an empty change list.
  test "a change to anything else notifies nobody" do
    @event.assign_attributes(email_from: "auskunft@ub.uni-paderborn.de", published: false, duration: 120)

    assert_no_emails do
      ParticipantMailer.change_notice(@event, @registration).deliver_now
    end
  end

  test "a linked change notice points to the detail page" do
    @registration.update!(ils_primary_id: "12345")
    @event.date_and_time = Time.zone.parse("2026-11-01 14:00")

    body = ParticipantMailer.change_notice(@event, @registration).body.to_s

    assert_includes body,
                    "geändert haben. Weitere Details finden Sie in Ihrem Benutzerkonto im Schulungsportal unter #{detail_url(@registration)}"
    assert_includes body, linked_cancel_info(@registration)
    assert_not_includes body, "\n\n\n"
  end

  test "an unlinked change notice does not mention the account" do
    @event.date_and_time = Time.zone.parse("2026-11-01 14:00")

    body = ParticipantMailer.change_notice(@event, @registration).body.to_s

    assert_includes body, "dass sich einige Daten der Veranstaltung geändert haben.\n"
    assert_not_includes body, "Benutzerkonto"
    assert_not_includes body, "/account"
    assert_not_includes body, "\n\n\n"
  end

  test "a user message keeps the staff subject and goes to the participant" do
    mail = ParticipantMailer.staff_message(@registration, room_change_message)

    assert_equal ["max@example.com"], mail.to
    assert_equal [TEAM], mail.from
    assert_equal [TEAM], mail.reply_to
    assert_equal "[UB Paderborn] Raumänderung", mail.subject
  end

  test "a user message answers to the address kept on the event" do
    @event.update!(email_from: "auskunft@ub.uni-paderborn.de")

    mail = ParticipantMailer.staff_message(@registration.reload, room_change_message)

    assert_equal ["auskunft@ub.uni-paderborn.de"], mail.reply_to
  end

  test "a user message carries the staff text below the context hint" do
    body = ParticipantMailer.staff_message(@registration, room_change_message).body.to_s

    assert_includes body, "Hallo Max Mustermann,"
    assert_includes body,
                    "im Zusammenhang mit Ihrer Anmeldung bei der Schulungsveranstaltung \"Literaturrecherche\" am 15.10.2026."
    assert_includes body, "Wir treffen uns in Raum 9."
    assert_includes body, "das Schulungsteam der UB Paderborn"
  end

  test "the certificate is attached under the given filename" do
    certify!

    mail = certificate_mail

    assert_equal ["max@example.com"], mail.to
    assert_equal [TEAM], mail.reply_to
    assert_equal "[UB Paderborn] Teilnahmebescheinigung: Literaturrecherche (15.10.2026)", mail.subject

    attachment = mail.attachments[CERTIFICATE_FILENAME]

    assert_not_nil attachment
    assert_equal "%PDF-1.7 fake", attachment.body.decoded
    assert_includes mail.text_part.body.to_s,
                    "anbei erhalten Sie Ihre Teilnahmebescheinigung für die Schulungsveranstaltung \"Literaturrecherche\" am 15.10.2026."
  end

  test "the certificate answers to the address kept on the event" do
    certify!
    @event.update!(email_from: "auskunft@ub.uni-paderborn.de")

    assert_equal ["auskunft@ub.uni-paderborn.de"], certificate_mail.reply_to
  end

  # Without a certification there is nothing to certify, and an anonymized
  # registration has no name and no address left to send it to.
  test "no certificate is built for an event without a certification" do
    assert_no_emails do
      certificate_mail.deliver_now
    end
  end

  test "no certificate is built for an anonymized registration" do
    certify!
    @registration.update_columns(first_name: "Gelöscht", last_name: "Gelöscht", email: "Gelöscht")

    assert_no_emails do
      certificate_mail.deliver_now
    end
  end

  test "a linked user message points to the detail page" do
    @registration.update!(ils_primary_id: "12345")

    body = ParticipantMailer.staff_message(@registration, room_change_message).body.to_s

    assert_includes body, "Wir treffen uns in Raum 9.\n\n#{registration_link(@registration)}\n\n"
    assert_not_includes body, "\n\n\n"
  end

  test "an unlinked user message does not mention the account" do
    body = ParticipantMailer.staff_message(@registration, room_change_message).body.to_s

    assert_not_includes body, "Benutzerkonto"
    assert_includes body, "Wir treffen uns in Raum 9.\n\nSollten Sie Fragen haben"
  end

  test "a linked certificate mail points to the detail page" do
    certify!
    @registration.update!(ils_primary_id: "12345")

    body = certificate_mail.text_part.body.to_s

    assert_includes body, registration_link(@registration)
    assert_not_includes body, "\n\n\n"
  end

  test "an unlinked certificate mail does not mention the account" do
    certify!

    body = certificate_mail.text_part.body.to_s

    assert_not_includes body, "Benutzerkonto"
    assert_not_includes body, "\n\n\n"
  end

end
