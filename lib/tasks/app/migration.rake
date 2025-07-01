namespace :app do
  namespace :migration do

    desc "Migrate the data from the old production database to the new one"
    task migrate_data: :environment do
      unless ENV["MIGRATION_PRODUCTION_DATABASE_PASSWORD"]
        $stderr.puts "MIGRATION_PRODUCTION_DATABASE_PASSWORD is not set"
        next
      end

      unless ENV["MIGRATION_TESTING_DATABASE_PASSWORD"]
        $stderr.puts "MIGRATION_TESTING_DATABASE_PASSWORD is not set"
        next
      end

      $stdout.puts "Are you sure? ALL EXISTING DATA WILL BE DELETED!! (y/n)"
      input = $stdin.gets.strip
      next unless input == "y"

      # Simulate progress
      puts "Migration started. This may take a while..."
      # Ractor.new do
      #   loop do
      #     print "."
      #     sleep 1
      #   end
      # end

      #
      # Delete all existing data
      #
      Report.destroy_all
      Registration.destroy_all
      Event.destroy_all
      Course.destroy_all
      Consulting.destroy_all
      Topic.destroy_all
      TargetGroup.destroy_all
      Certification.destroy_all
      Certificate.destroy_all
      Category.destroy_all

      #
      # Migrate courses
      #
      Migration::Production::Course.order(date_and_time: :desc).each do |old_course|
        course = Course.find_or_create_by!(title: old_course.title) do |course|
          course.id = old_course.id # Important for topic mapping below
          course.published = false  # Courses are not published by default
          course.description = old_course.description
          course.learning_targets = old_course.learning_targets
        end

        Event.create! do |event|
          event.id = old_course.id
          event.course = course
          event.date_and_time = old_course.date_and_time
          event.duration = old_course.duration
          event.location = old_course.location
          event.online = old_course.location&.downcase == "online"
          event.published = old_course.published
          event.reminder_message = old_course.reminder_message
          event.email_from = old_course.email_from
          event.registration_required = old_course.registration_required
          event.max_no_of_participants = old_course.max_no_of_participants
        end

        # Publish the course if any of the upcoming events are published
        course.update(published: true) if course.events.upcoming.any?(&:published)
      end

      #
      # Migrate registrations
      #
      Migration::Production::Registration.find_each do |old_registration|
        event = Event.find(old_registration.training_course_id)

        registration = Registration.new do |registration|
          registration.id = old_registration.id
          registration.event = event
          registration.first_name = old_registration.firstname
          registration.last_name = old_registration.lastname
          registration.email = old_registration.email
          registration.field_of_interest = old_registration.field_of_interest
          registration.user_notes = old_registration.notes
          registration.internal_notes = old_registration.internal_notes
          registration.gdrp_consent = old_registration.dsgvo_consent
          registration.reminder_message_sent_at = old_registration.sent_reminder_message_at
          registration.certificate_sent_at = old_registration.certificate_sent_at
          registration.created_at = old_registration.created_at
          registration.updated_at = old_registration.updated_at
        end

        # Because of the `validate: false` on the save operation we need to strip attributes manually
        StripAttributes.strip(registration, collapse_spaces: true)

        # We need to disable validation as old data might not be valid
        registration.save!(validate: false)
      end

      #
      # Migrate reports
      #
      Migration::Production::Course.find_each do |old_course|
        event = Event.find(old_course.id)
        next if old_course.statistics_duration.blank? || old_course.statistics_duration.zero? || old_course.statistics_lecturer.blank?

        Report.create! do |report|
          report.event = event
          report.duration = old_course.statistics_duration
          report.number_of_participants = old_course.number_of_participants
          report.lecturer = old_course.statistics_lecturer
          report.lecturer_md = old_course.statistics_lecturer_md
          report.lecturer_gd = old_course.statistics_lecturer_gd
          report.lecturer_hd = old_course.statistics_lecturer_hd
          report.presence_types = old_course.statistics_presence_types
          report.organization_types = old_course.statistics_organization_types
          report.forms = old_course.statistics_forms
          report.levels = old_course.statistics_levels
          report.categories = old_course.statistics_categories
          report.audiences = old_course.statistics_audiences
          report.focus = old_course.statistics_focus
        end
      end

      #
      # Migrate certifications
      #
      Migration::Production::Course.find_each do |old_course|
        event = Event.find(old_course.id)
        next if old_course.certificate_learning_results.blank?

        Certification.create! do |certification|
          certification.event = event
          certification.learning_results = old_course.certificate_learning_results
          certification.signature = old_course.certificate_signature
        end
      end

      #
      # Migrate certificates
      #
      Migration::Production::CertificationDigest.find_each do |old_certification_digest|
        registration = Registration.find(old_certification_digest.registration_id)

        Certificate.create! do |certificate|
          certificate.registration = registration
          certificate.digest = old_certification_digest.digest
          certificate.initials = old_certification_digest.initials
          certificate.created_at = old_certification_digest.created_at
          certificate.updated_at = old_certification_digest.updated_at
        end
      end

      #
      # Migrate topics
      #
      Topic.create!(id: 1, title: "Orientieren", position: 1) # Was ID 10, "Räumliche Orientierung"
      Topic.create!(id: 2, title: "Literatur suchen", position: 2) # Was ID 30 "Katalogbenutzung" AND ID 16 "Literaturrecherche"
      Topic.create!(id: 3, title: "Literatur verwalten", position: 3) # Was ID 14 "Literaturverwaltung"
      Topic.create!(id: 4, title: "Literatur bewerten", position: 4) # Was ID 33 "Literaturbewertung"
      Topic.create!(id: 5, title: "Schreiben", position: 5) # Is new (no mappings exists yet)
      Topic.create!(id: 6, title: "Veröffentlichen / Open Access", position: 6) # Was ID 35 "Open Access"

      map_production_topic_id = lambda { |production_topic_id|
        case production_topic_id
        when 10 # Räumliche Orientierung
          1 # Orientieren
        when 30, 16 # Katalogbenutzung or Literaturrecherche
          2 # Literatur suchen
        when 14 # Literaturverwaltung
          3 # Literatur verwalten
        when 33 # Literaturbewertung
          4 # Literatur bewerten
        when 35 # Open Access
          6 # Veröffentlichen / Open Access
        else
          raise "Unknown topic mapping detected!"
        end
      }

      Migration::Production::TopicMapping.all.each do |production_topic_mapping| # rubocop:disable Rails/FindEach
        next if production_topic_mapping.category_id == 32 # Skip the "Fernleihe" topic, as it is not used anymore

        course = Course.find_by(id: production_topic_mapping.training_course_id)
        topic = Topic.find_by(id: map_production_topic_id.call(production_topic_mapping.category_id))

        course.topics << topic if course && topic
      end

      #
      # Migrate target groups
      #
      TargetGroup.create!(id: 1, title: "Studierende", position: 1) # Was ID 2 "Studierende"
      TargetGroup.create!(id: 2, title: "International students", position: 2) # Was ID 8 "International students"
      TargetGroup.create!(id: 3, title: "Promovierende", position: 3) # Was ID 12 "Doktorandinnen und Doktoranden"
      TargetGroup.create!(id: 4, title: "Forschende und Lehrende", position: 4) # Was ID 14 "Forschende und Lehrende"
      TargetGroup.create!(id: 5, title: "Mitarbeitende der Universität", position: 5) # Was ID 18 "Beschäftigte der Universität"
      TargetGroup.create!(id: 6, title: "Interessierte aus Stadt und Region", position: 6) # Was ID 10 "Nutzerinnen und Nutzer aus Stadt und Umland Paderborn"
      TargetGroup.create!(id: 7, title: "Schulen", position: 7) # Was ID 6 "Schulen"

      map_production_target_group_id = lambda { |production_target_group_id|
        case production_target_group_id
        when 2 # Studierende
          1 # Studierende
        when 8 # International students
          2 # International students
        when 12 # Doktorandinnen und Doktoranden
          3 # Promovierende
        when 14 # Forschende und Lehrende
          4 # Forschende und Lehrende
        when 18 # Beschäftigte der Universität
          5 # Mitarbeitende der Universität
        when 10 # Nutzerinnen und Nutzer aus Stadt und Umland Paderborn
          6 # Interessierte aus Stadt und Region
        when 6 # Schulen
          7 # Schulen
        else
          raise "Unknown topic mapping detected!"
        end
      }

      Migration::Production::TargetGroupMapping.all.each do |production_target_group_mapping| # rubocop:disable Rails/FindEach
        next if production_target_group_mapping.target_audience_id == 16 # Skip the "Teamer" target group, as it is not used anymore
        next if production_target_group_mapping.target_audience_id == 4 # Skip the "Teilnehmende des Studiums für Ältere" target group, as it is not used anymore

        course = Course.find_by(id: production_target_group_mapping.training_course_id)
        target_group = TargetGroup.find_by(id: map_production_target_group_id.call(production_target_group_mapping.target_audience_id))

        course.target_groups << target_group if course && target_group
      end

      #
      # Migrate consultings from the current testing database
      #
      map_testing_target_group_id = lambda { |testing_target_group_id|
        case testing_target_group_id
        when 2 then 1 # Studierende
        when 8 then 2 # International students
        when 12 then 3 # Promovierende
        when 14 then 4 # Forschende und Lehrende
        when 18 then 5 # Mitarbeitende der Universität
        when 10 then 6 # Interessierte aus Stadt und Region
        when 6 then 7 # Schulen
        else
          raise "Unknown topic mapping detected!"
        end
      }

      map_testing_topic_id = lambda { |testing_topic_id|
        case testing_topic_id
        when 10 then 1 # Räumliche Orientierung
        when 16 then 2 # Literatur suchen
        when 35 then 3 # Literatur verwalten
        when 33 then 4 # Literatur bewerten
        when 14 then 5 # Schreiben
        when 36 then 6 # Veröffentlichen / Open Access
        else
          raise "Unknown topic mapping detected!"
        end
      }

      Migration::Testing::Consulting.find_each do |testing_consulting|
        consulting = Consulting.create! do |consulting|
          consulting.id = testing_consulting.id
          consulting.title = testing_consulting.title
          consulting.published = testing_consulting.published
          consulting.description = testing_consulting.description
          consulting.contact_name = testing_consulting.contact_name
          consulting.contact_email = testing_consulting.contact_email
          consulting.contact_phone = testing_consulting.contact_phone
          consulting.created_at = testing_consulting.created_at
          consulting.updated_at = testing_consulting.updated_at
        end

        testing_consulting.target_groups.each do |testing_target_group|
          target_group_id = map_testing_target_group_id.call(testing_target_group.id)
          target_group = TargetGroup.find(target_group_id)

          consulting.target_groups << target_group
        end

        testing_consulting.topics.each do |testing_topic|
          topic_id = map_testing_topic_id.call(testing_topic.id)
          topic = Topic.find(topic_id)

          consulting.topics << topic
        end
      end
    end
  end
end
