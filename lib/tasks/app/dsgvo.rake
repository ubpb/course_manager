namespace :app do
  namespace :dsgvo do
    desc "Cleanup personal information to be GDRP compliant"
    task cleanup: :environment do
      DsgvoCleanupJob.perform_now
    end

    # Anonymizes every registration, whatever the date of its event, for systems
    # that must not hold personal data. Every server runs in the production
    # environment, so the database name serves as confirmation.
    desc "Anonymize ALL registrations and drop all queued jobs (CONFIRM=<database name>)"
    task anonymize_all: :environment do
      database = ActiveRecord::Base.connection_db_config.database

      unless ENV["CONFIRM"] == database
        abort "This anonymizes ALL registrations in #{database} and drops all queued jobs.\n" \
              "Run again with CONFIRM=#{database} to proceed."
      end

      # Beyond what the cleanup clears, the internal notes go as well.
      attributes = Registration::ANONYMIZED_ATTRIBUTES.merge(internal_notes: nil)
      registrations = Registration.update_all(attributes) # rubocop:disable Rails/SkipsModelValidations
      # Queued jobs carry personal data too, mails above all (names, addresses).
      jobs = SolidQueue::Job.delete_all

      puts "#{database}: #{registrations} registrations anonymized, #{jobs} queued jobs dropped."
    end
  end
end
