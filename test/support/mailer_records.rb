# Every mailer needs the same offer -> event -> registration chain, so the mailer
# tests build it through these helpers instead of repeating the attribute lists.
module MailerRecords

  EVENT_TIME = "2026-10-15 10:00".freeze

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
