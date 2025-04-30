namespace :app do
  namespace :migration do

    desc "Migrate the data from the old database to the new one"
    task migrate_data: :environment do
      $stdout.puts "Are you sure? ALL EXISTING DATA WILL BE DELETED!! (y/n)"
      input = $stdin.gets.strip
      next unless input == "y"

      #
      # Migrate courses
      #
      Course.destroy_all
      OldCourse.order(date_and_time: :desc).each do |old_course|
        course = Course.find_or_create_by!(title: old_course.title) do |course|
          course.id = old_course.id # Important for topic mapping below
          course.published = false
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
      Registration.destroy_all
      OldRegistration.find_each do |old_registration|
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
      Report.destroy_all
      OldCourse.find_each do |old_course|
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
      Certification.destroy_all
      OldCourse.find_each do |old_course|
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
      Certificate.destroy_all
      OldCertificationDigest.find_each do |old_certification_digest|
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
      Topic.destroy_all
      OldTopic.order(position: :asc).each.with_index(1) do |old_topic, i|
        Topic.create! do |topic|
          topic.id = old_topic.id
          topic.title = old_topic.title
          topic.position = i
        end
      end

      OldTopicMapping.all.each do |old_topic_mapping| # rubocop:disable Rails/FindEach
        course = Course.find_by(id: old_topic_mapping.training_course_id)
        topic = Topic.find_by(id: old_topic_mapping.category_id)

        course.topics << topic if course && topic
      end

      #
      # Migrate target groups
      #
      TargetGroup.destroy_all
      OldTargetGroup.order(position: :asc).each.with_index(1) do |old_target_group, i|
        TargetGroup.create! do |target_group|
          target_group.id = old_target_group.id
          target_group.title = old_target_group.title
          target_group.position = i
        end
      end

      OldTargetGroupMapping.all.each do |old_target_group_mapping| # rubocop:disable Rails/FindEach
        course = Course.find_by(id: old_target_group_mapping.training_course_id)
        target_group = TargetGroup.find_by(id: old_target_group_mapping.target_audience_id)

        course.target_groups << target_group if course && target_group
      end

      #
      # Create categories
      #
      Category.destroy_all
      Category.create!(title: "Orientieren", color_code: "#000000", position: 1)
      Category.create!(title: "Literatur suchen", color_code: "#000000", position: 2)
      Category.create!(title: "Literatur verwalten", color_code: "#000000", position: 3)
      Category.create!(title: "Literatur bewerten", color_code: "#000000", position: 4)
      Category.create!(title: "Schreiben", color_code: "#000000", position: 5)
      Category.create!(title: "Veröffentlichen", color_code: "#000000", position: 6)
    end
  end
end
