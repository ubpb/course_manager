require "test_helper"

# Mails staff trigger from the admin for a single registration: a free text
# message and the certificate of attendance.
class Admin::RegistrationsMailerTest < ActionMailer::TestCase

  include MailerRecords

  TEAM = "schulung@ub.uni-paderborn.de".freeze
  CERTIFICATE_FILENAME = "Teilnahmebescheinigung.pdf".freeze

  setup do
    @offer = create_offer
    @event = create_event
    @registration = create_registration
  end

  def staff_message
    Message.new(subject: "Raumänderung", body: "Wir treffen uns in Raum 9.")
  end

  def certificate_mail
    Admin::Mailers::RegistrationsMailer.certificate(@registration, "%PDF-1.7 fake", CERTIFICATE_FILENAME)
  end

  def certify!
    Certification.create!(event: @event, learning_results: "Katalogrecherche", signature: "Max Muster")
    @registration.reload
  end

  test "a user message keeps the staff subject and goes to the participant" do
    mail = Admin::Mailers::RegistrationsMailer.user_message(@registration, staff_message)

    assert_equal ["max@example.com"], mail.to
    assert_equal [TEAM], mail.from
    assert_equal [TEAM], mail.reply_to
    assert_equal "[UB Paderborn] Raumänderung", mail.subject
  end

  test "a user message answers to the address kept on the event" do
    @event.update!(email_from: "auskunft@ub.uni-paderborn.de")

    mail = Admin::Mailers::RegistrationsMailer.user_message(@registration.reload, staff_message)

    assert_equal ["auskunft@ub.uni-paderborn.de"], mail.reply_to
  end

  test "a user message carries the staff text below the context hint" do
    body = Admin::Mailers::RegistrationsMailer.user_message(@registration, staff_message).body.to_s

    assert_includes body, "Hallo Max Mustermann,"
    assert_includes body, "im Zusammenhang mit Ihrer Anmeldung bei der Schulungsveranstaltung \"Literaturrecherche\" am 15.10.2026."
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
    assert_includes mail.text_part.body.to_s, "anbei erhalten Sie Ihre Teilnahmebescheinigung für die Schulungsveranstaltung \"Literaturrecherche\" am 15.10.2026."
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

    body = Admin::Mailers::RegistrationsMailer.user_message(@registration, staff_message).body.to_s

    assert_includes body, "Wir treffen uns in Raum 9.\n\n#{registration_link(@registration)}\n\n"
    assert_not_includes body, "\n\n\n"
  end

  test "an unlinked user message does not mention the account" do
    body = Admin::Mailers::RegistrationsMailer.user_message(@registration, staff_message).body.to_s

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
