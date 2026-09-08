require "test_helper"

# Both participant mails that name a place render the same location partial. It
# has to choose between the online link, the fallback for an online event whose
# link is not known yet, and the on site meeting point -- and it must never show
# two of them at once.
class LocationInfoTest < ActionMailer::TestCase

  include MailerRecords

  ONLINE_INTRO = "Die Veranstaltung findet online statt."
  NO_LINK_YET = "Zugangsdaten erhalten Sie vor der Veranstaltung in einer separaten E-Mail."
  MEETING_POINT = "Ort / Treffpunkt: \"Raum 1.2\"."

  setup do
    @offer = create_offer
    @event = create_event
    @registration = create_registration
  end

  # The confirmation and the reminder render the partial from different
  # templates, so every variant is asserted against both bodies.
  def bodies
    [
      Frontend::Mailers::RegistrationsMailer.confirmation(@registration).body.to_s,
      Admin::Mailers::EventsMailer.reminder_message(@registration, skip_if_sent: false).body.to_s
    ]
  end

  test "an online event with a link sends the link" do
    @event.update!(online: true, online_url: "https://meet.example.com/abc", location: nil)

    bodies.each do |body|
      assert_includes body, "#{ONLINE_INTRO} Zugangslink: https://meet.example.com/abc\n"
      assert_not_includes body, NO_LINK_YET
      assert_not_includes body, "Ort / Treffpunkt"
    end
  end

  test "the link of an online event wins over a leftover location" do
    @event.update!(online: true, online_url: "https://meet.example.com/abc", location: "Raum 1.2")

    bodies.each do |body|
      assert_includes body, "Zugangslink: https://meet.example.com/abc"
      assert_not_includes body, "Ort / Treffpunkt"
    end
  end

  test "an online event without a link announces the access data separately" do
    @event.update!(online: true, online_url: nil, location: nil)

    bodies.each do |body|
      assert_includes body, "#{ONLINE_INTRO} #{NO_LINK_YET}\n"
      assert_not_includes body, "Zugangslink"
    end
  end

  test "an empty link counts as no link" do
    @event.update!(online: true, online_url: "", location: "Raum 1.2")

    bodies.each do |body|
      assert_includes body, "#{ONLINE_INTRO} #{NO_LINK_YET}\n"
      assert_not_includes body, "Zugangslink"
      assert_not_includes body, "Ort / Treffpunkt"
    end
  end

  test "an on site event names the meeting point" do
    @event.update!(online: false, location: "Raum 1.2")

    bodies.each do |body|
      assert_includes body, "#{MEETING_POINT}\n"
      assert_not_includes body, ONLINE_INTRO
    end
  end

  test "the online flag decides, not a leftover link" do
    @event.update!(online: false, online_url: "https://meet.example.com/abc", location: "Raum 1.2")

    bodies.each do |body|
      assert_includes body, MEETING_POINT
      assert_not_includes body, ONLINE_INTRO
      assert_not_includes body, "https://meet.example.com/abc"
    end
  end

  test "an on site event without a location says nothing about the place" do
    @event.update!(online: false, location: nil)

    bodies.each do |body|
      assert_not_includes body, "Ort / Treffpunkt"
      assert_not_includes body, ONLINE_INTRO
      assert_not_includes body, NO_LINK_YET
      # The partial brings its own blank line, so leaving it out must not leave
      # a gap behind either.
      assert_not_includes body, "\n\n\n"
    end
  end

  test "a blank location counts as no location" do
    @event.update!(online: false, location: "")

    bodies.each do |body|
      assert_not_includes body, "Ort / Treffpunkt"
      assert_not_includes body, ONLINE_INTRO
      assert_not_includes body, "\n\n\n"
    end
  end

  # The confirmation puts the custom staff text right after the place, so it has
  # to close up when there is no place to print.
  test "the custom confirmation text follows an omitted location without a gap" do
    @event.update!(online: false, location: nil, confirmation_message: "Bitte ###NAME### mitbringen.")

    body = Frontend::Mailers::RegistrationsMailer.confirmation(@registration).body.to_s

    assert_includes body, "Die Veranstaltung beginnt um 10:00 Uhr.\n\nBitte Max Mustermann mitbringen.\n\nSollten Sie den Termin"
    assert_not_includes body, "\n\n\n"
  end

  test "the location stands on its own line between the intro and the cancel hint" do
    @event.update!(online: false, location: "Raum 1.2")

    bodies.each do |body|
      assert_includes body, "\n\n#{MEETING_POINT}\n\nSollten Sie den Termin nicht wahrnehmen können"
    end
  end

end
