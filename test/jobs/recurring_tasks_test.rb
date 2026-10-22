require "test_helper"

# Solid Queue's scheduler runs what the server's crontab used to run. Solid
# Queue only reads the section of the current environment, so the production
# tasks are checked here directly.
class RecurringTasksTest < ActiveSupport::TestCase

  def production_task(key)
    config = ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/recurring.yml")).deep_symbolize_keys
    options = config.fetch(:production).fetch(key)

    SolidQueue::RecurringTask.from_configuration(key, **options, static: true)
  end

  test "the reminder mails go out every morning" do
    task = production_task(:send_reminder_messages)

    assert_predicate task, :valid?, task.errors.full_messages.to_sentence
    assert_equal "SendReminderMessagesJob", task.class_name

    travel_to Time.zone.parse("2026-10-22 12:00") do
      assert_equal Time.zone.parse("2026-10-23 06:00"), task.next_time
    end
  end

  test "personal data is cleaned up every morning" do
    task = production_task(:dsgvo_cleanup)

    assert_predicate task, :valid?, task.errors.full_messages.to_sentence
    assert_equal "DsgvoCleanupJob", task.class_name

    travel_to Time.zone.parse("2026-10-22 12:00") do
      assert_equal Time.zone.parse("2026-10-23 05:00"), task.next_time
    end
  end

  # The schedules are read in the app's time zone (Berlin), so a change to
  # summer or winter time does not shift them.
  test "the schedules follow Berlin time across the change to winter time" do
    task = production_task(:send_reminder_messages)

    travel_to Time.zone.parse("2026-10-24 12:00") do
      assert_equal Time.zone.parse("2026-10-25 06:00"), task.next_time
      assert_equal "+01:00", task.next_time.in_time_zone.formatted_offset
    end
  end

end
