namespace :app do
  namespace :mailer do

    desc "Send reminder messages."
    task send_reminder_messages: :environment do
      Event.includes(:course, :registrations).upcoming.where("date_and_time <= ?", 3.days.from_now.end_of_day).find_each do |event|
        event.registrations.each do |registration|
          next if registration.reminder_message_sent_at.present?

          Admin::Mailers::EventsMailer.reminder_message(registration).deliver
          registration.update_column(:reminder_message_sent_at, Time.zone.now) # rubocop:disable Rails/SkipsModelValidations
        end
      end
    end

  end
end
