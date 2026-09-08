namespace :app do
  namespace :mailer do

    desc "Send the reminder mail to every participant of an event taking place within the next three days."
    task send_reminder_messages: :environment do
      # Events that have already started are left out: a reminder for them would
      # arrive after the fact.
      events = Event.includes(:offer).where(date_and_time: Time.zone.now..3.days.from_now.end_of_day)

      events.find_each do |event|
        event.registrations.where(reminder_message_sent_at: nil).find_each do |registration|
          next if registration.anonymized?

          # Claim the registration before sending: the UPDATE only matches while
          # the column is still NULL, so neither a second run of the task nor a
          # second process can send the same reminder twice.
          claimed = Registration.where(id: registration.id, reminder_message_sent_at: nil)
                                .update_all(reminder_message_sent_at: Time.zone.now) # rubocop:disable Rails/SkipsModelValidations
          next if claimed.zero?

          # Read the claim back instead of reusing the Time we wrote: the column
          # may store it with less precision, and the release below has to match
          # the stored value exactly.
          claimed_at = registration.reload.reminder_message_sent_at

          # The claim above has taken the place of the mailer's own guard, which
          # would now see the timestamp and skip the delivery.
          Admin::Mailers::EventsMailer.reminder_message(registration, skip_if_sent: false).deliver
        rescue StandardError => e
          # Release our own claim -- and only ours, so a reminder someone sent
          # from the admin in the meantime is left alone -- to have the next run
          # try again. The mail may still have gone out before the error, so a
          # retry can duplicate it: losing a reminder to a transient fault is
          # considered the worse outcome.
          if claimed_at
            Registration.where(id: registration.id, reminder_message_sent_at: claimed_at)
                        .update_all(reminder_message_sent_at: nil) # rubocop:disable Rails/SkipsModelValidations
          end

          warn "Erinnerungsmail an Anmeldung ##{registration.id} fehlgeschlagen: #{e.class}: #{e.message}"
        end
      end
    end

  end
end
