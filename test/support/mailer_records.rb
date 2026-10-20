# Every mailer needs the same offer -> event -> registration chain, so the mailer
# tests build it through these helpers instead of repeating the attribute lists.
module MailerRecords

  EVENT_TIME = "2026-10-15 10:00".freeze

  # The cancel hint for a registration without an account, which can only be
  # cancelled by replying to the mail.
  UNLINKED_CANCEL_INFO = "Sollten Sie den Termin nicht wahrnehmen können, bitten wir Sie, " \
                         "uns dies rechtzeitig mitzuteilen. Antworten Sie dazu einfach auf diese E-Mail.".freeze

  def detail_url(registration)
    "http://example.com/account/anmeldungen/#{registration.id}"
  end

  def linked_cancel_info(registration)
    "Alle Informationen zu Ihrer Anmeldung finden Sie in Ihrem Benutzerkonto im " \
      "Schulungs- und Beratungsportal. Sollten Sie den Termin nicht wahrnehmen können, melden " \
      "Sie sich dort bitte rechtzeitig ab: #{detail_url(registration)}"
  end

  def registration_link(registration)
    "Alle Informationen zu Ihrer Anmeldung finden Sie in Ihrem Benutzerkonto: #{detail_url(registration)}"
  end

  def create_offer(**attributes)
    Offer.create!({title: "Literaturrecherche", type: "course", published: true}.merge(attributes))
  end

  def create_event(offer = @offer, **attributes)
    offer.events.create!({date_and_time: Time.zone.parse(EVENT_TIME),
                          duration: 90,
                          location: "Raum 1.2",
                          max_no_of_participants: 10,
                          registration_required: true,
                          published: true}.merge(attributes))
  end

  def create_registration(event = @event, **attributes)
    event.registrations.create!({first_name: "Max",
                                 last_name: "Mustermann",
                                 email: "max@example.com"}.merge(attributes))
  end

end
