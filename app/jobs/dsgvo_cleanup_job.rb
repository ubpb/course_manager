# Anonymizes the personal data of registrations once the retention period after
# their event is over. Runs daily as a recurring task (config/recurring.yml);
# `bin/rails app:dsgvo:cleanup` runs it by hand.
class DsgvoCleanupJob < ApplicationJob

  def perform
    Event.includes(:registrations).where(date_and_time: ..Registration::RETENTION_PERIOD.ago).find_each do |event|
      event.registrations.each do |r|
        r.update_columns(Registration::ANONYMIZED_ATTRIBUTES) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end

end
