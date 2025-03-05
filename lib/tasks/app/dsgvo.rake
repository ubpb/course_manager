namespace :app do
  namespace :dsgvo do

    desc "Cleanup personal information to be GDRP compliant"
    task cleanup: :environment do
      Event.includes(:registrations).where("date_and_time <= ?", 10.days.ago).find_each do |event|
        event.registrations.each do |r|
          # Update registration and skipping validations
          r.update_columns( # rubocop:disable Rails/SkipsModelValidations
            first_name: "Gelöscht",
            last_name: "Gelöscht",
            email: "Gelöscht",
            field_of_interest: nil,
            user_notes: nil
          )
        end
      end
    end

  end
end
