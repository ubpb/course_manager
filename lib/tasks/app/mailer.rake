namespace :app do
  namespace :mailer do
    desc "Send the reminder mail to every participant of an event taking place within the next three days."
    task send_reminder_messages: :environment do
      SendReminderMessagesJob.perform_now
    end
  end
end
