require "test_helper"
require "rake"

# Anonymizing everything leaves no personal data behind -- neither in the
# registrations nor in queued jobs -- and so nothing to send either.
class DsgvoAnonymizeAllTest < ActiveSupport::TestCase

  include ActionMailer::TestHelper
  include MailerRecords

  TASK = "app:dsgvo:anonymize_all".freeze

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?(TASK)

    @offer = create_offer
    @upcoming = create_registration(create_event(date_and_time: 2.days.from_now),
                                    ils_primary_id: "12345", internal_notes: "Rollstuhl", user_notes: "Komme später")
    @manual = create_registration(create_event(date_and_time: 1.month.from_now), email: "erika@example.com")
    @queued_mail = SolidQueue::Job.create!(queue_name: "default", class_name: "ActionMailer::MailDeliveryJob",
                                           arguments: {"arguments" => ["Erika", "erika@example.com"]})
    @database = ActiveRecord::Base.connection_db_config.database
  end

  def run_task(confirm: nil)
    ENV["CONFIRM"] = confirm
    Rake::Task[TASK].reenable
    capture_io { Rake::Task[TASK].invoke }
  ensure
    ENV.delete("CONFIRM")
  end

  test "without the database name as confirmation nothing happens" do
    [nil, "course_manager_production"].each do |confirm|
      assert_raises(SystemExit) { run_task(confirm: confirm) }
    end

    assert_equal "Max", @upcoming.reload.first_name
    assert SolidQueue::Job.exists?(@queued_mail.id)
  end

  test "every registration is anonymized, whatever the date of its event" do
    run_task(confirm: @database)

    [@upcoming, @manual].each do |registration|
      registration.reload

      assert_predicate registration, :anonymized?
      assert_nil registration.ils_primary_id
      assert_nil registration.user_notes
      assert_nil registration.internal_notes
    end
  end

  test "queued jobs are dropped" do
    run_task(confirm: @database)

    assert_equal 0, SolidQueue::Job.count
  end

  test "afterwards the reminders reach nobody" do
    run_task(confirm: @database)

    assert_no_emails do
      SendReminderMessagesJob.perform_now
    end
  end

end
