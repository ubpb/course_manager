require "test_helper"

# Mails that concern the event itself: the reminder before it starts and the
# notice that its date or meeting point moved.
class Admin::EventsMailerTest < ActionMailer::TestCase

  include MailerRecords

  TEAM = "schulung@ub.uni-paderborn.de".freeze

  setup do
    @offer = create_offer
    @event = create_event
    @registration = create_registration
  end

  def reminder(**options)
    Admin::Mailers::EventsMailer.reminder_message(@registration, **options)
  end

  test "the reminder goes to the participant with date, time and place" do
    mail = reminder(skip_if_sent: false)

    assert_equal ["max@example.com"], mail.to
    assert_equal [TEAM], mail.from
    assert_equal [TEAM], mail.reply_to
    assert_equal "[UB Paderborn] Informationen zu Ihrer Schulungsveranstaltung", mail.subject

    body = mail.body.to_s

    assert_includes body, "Hallo Max Mustermann,"
    assert_includes body, "wir möchten Sie an Ihre Anmeldung zu unserer Schulungsveranstaltung \"Literaturrecherche\" erinnern."
    assert_includes body, "Termin: 15.10.2026"
    assert_includes body, "Uhrzeit: 10:00 Uhr"
    assert_includes body, "Ort / Treffpunkt: \"Raum 1.2\"."
    assert_includes body, "klicken beim Termin auf \"abmelden\": http://example.com/account"
    assert_includes body, "das Schulungsteam der UB Paderborn"
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
      Admin::Mailers::EventsMailer.changed_notification(@event, @registration).deliver_now
    end
  end

  test "a moved date is reported with the old and the new value" do
    @event.date_and_time = Time.zone.parse("2026-11-01 14:00")

    mail = Admin::Mailers::EventsMailer.changed_notification(@event, @registration)

    assert_equal ["max@example.com"], mail.to
    assert_equal [TEAM], mail.reply_to
    assert_equal "[UB Paderborn] Änderung eines Schulungstermins", mail.subject

    body = mail.body.to_s

    assert_includes body, "Hallo Max Mustermann,"
    assert_includes body, "Datum/Uhrzeit"
    assert_includes body, "Bisher: 15.10.2026, 10:00 Uhr"
    assert_includes body, "NEU: 01.11.2026, 14:00 Uhr"
    assert_not_includes body, "Treffpunkt"
    # Only a moved date is worth an early cancellation.
    assert_includes body, "klicken beim Termin auf \"abmelden\": http://example.com/account"
  end

  test "a moved meeting point is reported without the cancel hint" do
    @event.location = "Raum 9"

    body = Admin::Mailers::EventsMailer.changed_notification(@event, @registration).body.to_s

    assert_includes body, "Treffpunkt"
    assert_includes body, "Bisher: Raum 1.2"
    assert_includes body, "NEU: Raum 9"
    assert_not_includes body, "Datum/Uhrzeit"
    assert_not_includes body, "klicken beim Termin auf \"abmelden\""
  end

  test "a new access link is reported with the old and the new value" do
    @event.update!(online: true, online_url: "https://meet.example.com/abc", location: nil)
    @event.online_url = "https://meet.example.com/xyz"

    mail = Admin::Mailers::EventsMailer.changed_notification(@event, @registration)

    assert_equal ["max@example.com"], mail.to
    assert_equal "[UB Paderborn] Änderung eines Schulungstermins", mail.subject

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

    body = Admin::Mailers::EventsMailer.changed_notification(@event, @registration).body.to_s

    assert_includes body, "Bisher: nicht angegeben"
    assert_includes body, "NEU: https://meet.example.com/abc"
  end

  test "a removed meeting point is reported against the same placeholder" do
    @event.location = nil

    body = Admin::Mailers::EventsMailer.changed_notification(@event, @registration).body.to_s

    assert_includes body, "Bisher: Raum 1.2"
    assert_includes body, "NEU: nicht angegeben"
  end

  test "date and meeting point moving together are both reported" do
    @event.assign_attributes(date_and_time: Time.zone.parse("2026-11-01 14:00"), location: "Raum 9")

    body = Admin::Mailers::EventsMailer.changed_notification(@event, @registration).body.to_s

    assert_includes body, "Bisher: 15.10.2026, 10:00 Uhr"
    assert_includes body, "NEU: 01.11.2026, 14:00 Uhr"
    assert_includes body, "Bisher: Raum 1.2"
    assert_includes body, "NEU: Raum 9"
  end

  test "every reported change gets its own block, separated by a single blank line" do
    @event.assign_attributes(date_and_time: Time.zone.parse("2026-11-01 14:00"), location: "Raum 9")

    body = Admin::Mailers::EventsMailer.changed_notification(@event, @registration).body.to_s

    assert_includes body, "Es gab folgende Änderungen:\n\nDatum/Uhrzeit"
    assert_includes body, "http://example.com/account\n\nTreffpunkt"
    assert_includes body, "NEU: Raum 9\n\nSollten Sie Fragen haben"
    assert_not_includes body, "\n\n\n"
  end

  test "a moved date and a switched form are both reported" do
    @event.assign_attributes(date_and_time: Time.zone.parse("2026-11-01 14:00"), online: true)

    body = Admin::Mailers::EventsMailer.changed_notification(@event, @registration).body.to_s

    assert_includes body, "NEU: 01.11.2026, 14:00 Uhr"
    assert_includes body, "http://example.com/account\n\nVeranstaltungsform"
    assert_includes body, "NEU: online"
    assert_not_includes body, "\n\n\n"
  end

  # A switched form changes where the participant has to show up, so the block
  # states the new arrangement instead of leaving it to a second block.
  test "switching to online is reported together with the access link" do
    @event.assign_attributes(online: true, online_url: "https://meet.example.com/abc")

    body = Admin::Mailers::EventsMailer.changed_notification(@event, @registration).body.to_s

    assert_includes body, "Veranstaltungsform\n------------------\nBisher: vor Ort\nNEU: online\n"
    assert_includes body, "Die Veranstaltung findet online statt. Zugangslink: https://meet.example.com/abc"
    assert_not_includes body, "Zugangslink\n-----------"
    assert_not_includes body, "Treffpunkt"
  end

  test "switching to online without a link points to the separate mail" do
    @event.online = true

    body = Admin::Mailers::EventsMailer.changed_notification(@event, @registration).body.to_s

    assert_includes body, "NEU: online"
    assert_includes body, "Zugangsdaten erhalten Sie vor der Veranstaltung in einer separaten E-Mail."
    assert_not_includes body, "Zugangslink"
  end

  test "switching back on site names the meeting point again" do
    @event.update!(online: true, online_url: "https://meet.example.com/abc")
    @event.online = false

    body = Admin::Mailers::EventsMailer.changed_notification(@event, @registration).body.to_s

    assert_includes body, "Veranstaltungsform\n------------------\nBisher: online\nNEU: vor Ort\n"
    assert_includes body, "Ort / Treffpunkt: \"Raum 1.2\"."
    assert_not_includes body, "https://meet.example.com/abc"
  end

  # The two place attributes are only worth a mail for the form the event is
  # actually held in.
  test "a link change on an on site event notifies nobody" do
    @event.online_url = "https://meet.example.com/abc"

    assert_no_emails do
      Admin::Mailers::EventsMailer.changed_notification(@event, @registration).deliver_now
    end
  end

  test "a meeting point change on an online event notifies nobody" do
    @event.update!(online: true, online_url: "https://meet.example.com/abc")
    @event.location = "Raum 9"

    assert_no_emails do
      Admin::Mailers::EventsMailer.changed_notification(@event, @registration).deliver_now
    end
  end

  # Only date and meeting point are reported, so any other edit would produce a
  # notice with an empty change list.
  test "a change to anything else notifies nobody" do
    @event.assign_attributes(email_from: "auskunft@ub.uni-paderborn.de", published: false, duration: 120)

    assert_no_emails do
      Admin::Mailers::EventsMailer.changed_notification(@event, @registration).deliver_now
    end
  end

end
