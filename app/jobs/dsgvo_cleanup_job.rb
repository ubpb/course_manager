# Anonymizes the personal data of registrations once the retention period after
# their event is over. Runs daily as a recurring task (config/recurring.yml);
# `bin/rails app:dsgvo:cleanup` runs it by hand.
class DsgvoCleanupJob < ApplicationJob

  def perform
    Event.includes(:registrations).where("date_and_time <= ?", Registration::RETENTION_PERIOD.ago).find_each do |event|
      event.registrations.each do |r|
        # Update registration and skipping validations
        r.update_columns( # rubocop:disable Rails/SkipsModelValidations
          first_name: "Gelöscht",
          last_name: "Gelöscht",
          email: "Gelöscht",
          ils_primary_id: nil,
          field_of_interest: nil,
          user_notes: nil
        )
      end
    end
  end

end
