# Internal notices to the training team.
class TeamMailer < ApplicationMailer

  TEAM_ADDRESS = "schulung@ub.uni-paderborn.de".freeze

  def new_registration(registration)
    @registration = registration
    @event = registration.event
    @offer = @event.offer

    mail(
      to: TEAM_ADDRESS,
      subject: "[SchulungsDB] Eine neue Anmeldung"
    )
  end

  # Die Registration ist zu diesem Zeitpunkt bereits gelöscht, daher werden
  # die benötigten Daten als einfache Werte übergeben (Active Job kann keine
  # Records ohne id serialisieren).
  def cancelled_registration(event, full_name:, email:)
    @event = event
    @offer = event.offer
    @full_name = full_name
    @email = email

    mail(
      to: TEAM_ADDRESS,
      subject: "[SchulungsDB] Eine Anmeldung wurde storniert"
    )
  end

end
