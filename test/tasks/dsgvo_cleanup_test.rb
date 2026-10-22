require "test_helper"
require "rake"

# Personal data is wiped a fixed period after the event. The detail page in
# the account announces the date, so the task and the page must agree on it.
class DsgvoCleanupTest < ActiveSupport::TestCase

  include MailerRecords

  TASK = "app:dsgvo:cleanup"

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?(TASK)

    @offer = create_offer
  end

  def run_task
    Rake::Task[TASK].reenable
    Rake::Task[TASK].invoke
  end

  def registration_at(date_and_time)
    create_registration(create_event(date_and_time: date_and_time), ils_primary_id: "12345")
  end

  test "registrations are anonymized once the retention period is over" do
    registration = registration_at(Registration::RETENTION_PERIOD.ago - 1.hour)

    run_task

    registration.reload

    assert_predicate registration, :anonymized?
    assert_nil registration.ils_primary_id
  end

  # The scheduler runs the job (config/recurring.yml); the rake task is the way
  # to run it by hand. Both do the same.
  test "the job anonymizes just like the task" do
    registration = registration_at(Registration::RETENTION_PERIOD.ago - 1.hour)

    DsgvoCleanupJob.perform_now

    assert_predicate registration.reload, :anonymized?
  end

  test "registrations within the retention period are kept" do
    registration = registration_at(Registration::RETENTION_PERIOD.ago + 1.hour)

    run_task

    assert_equal "Max", registration.reload.first_name
    assert_equal "12345", registration.ils_primary_id
  end

end
