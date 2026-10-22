require "test_helper"

# The internal notices to the training team about new and cancelled
# registrations.
class TeamMailerTest < ActionMailer::TestCase

  include MailerRecords

  TEAM = "schulung@ub.uni-paderborn.de".freeze

  setup do
    @offer = create_offer
    @event = create_event
    @registration = create_registration
  end

  test "the notification goes to the team with the registration data" do
    mail = TeamMailer.new_registration(@registration)

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

  test "the cancellation notification tells the team who left" do
    mail = TeamMailer.cancelled_registration(
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

end
