require "test_helper"

# What the monitoring learns about Solid Queue: whether its processes are alive,
# how the jobs stand and whether the recurring tasks ran. The report states
# facts; the monitoring judges them.
class SolidQueueHealthTest < ActiveSupport::TestCase

  setup { travel_to Time.utc(2026, 11, 11, 8, 15) }

  def report
    JSON.parse(JSON.generate(SolidQueueHealth.new.to_h))
  end

  def enqueue_job(class_name: "SendReminderMessagesJob", **attributes)
    SolidQueue::Job.create!(queue_name: "default", class_name: class_name, arguments: {}, **attributes)
  end

  # Runs a job the way a worker does: it leaves the ready jobs and ends up
  # finished or failed.
  def finish_job(job)
    job.ready_execution.destroy!
    job.finished!
  end

  def fail_job(job, exception)
    job.ready_execution.destroy!
    job.failed_with(exception)
  end

  def register_process(kind, **attributes)
    SolidQueue::Process.create!(kind: kind, name: "#{kind.downcase}-#{SecureRandom.hex(4)}", pid: 4711,
                                hostname: "batch", last_heartbeat_at: Time.current, **attributes)
  end

  def with_rails_env(name)
    original = Rails.env
    Rails.env = name
    yield
  ensure
    Rails.env = original
  end

  def with_env(name, value)
    original = ENV.fetch(name, nil)
    ENV[name] = value
    yield
  ensure
    ENV[name] = original
  end

  test "the report names the application, its environment and its time" do
    assert_equal "course_manager", report["app"]
    assert_equal "test", report["environment"]
    assert_equal "2026-11-11T08:15:00Z", report["generated_at"]
  end

  test "each registered process shows how long ago it sent its last heartbeat" do
    register_process("Worker", pid: 4712, last_heartbeat_at: 20.seconds.ago)

    assert_equal [{"kind" => "Worker", "hostname" => "batch", "pid" => 4712,
                   "last_heartbeat_at" => "2026-11-11T08:14:40Z", "heartbeat_age" => 20}],
                 report["processes"]["registered"]
  end

  test "a process counts as alive within the threshold Solid Queue itself applies" do
    original = SolidQueue.process_alive_threshold
    SolidQueue.process_alive_threshold = 2.minutes

    assert_equal 120, report["processes"]["alive_threshold"]
  ensure
    SolidQueue.process_alive_threshold = original
  end

  test "the processes to expect follow the queue configuration" do
    assert_equal({"Supervisor" => 1, "Dispatcher" => 1, "Worker" => 1}, report["processes"]["expected"])
  end

  test "every worker process is expected" do
    with_env("JOB_CONCURRENCY", "2") do
      assert_equal 2, report["processes"]["expected"]["Worker"]
    end
  end

  test "in production a scheduler is expected for the recurring tasks" do
    with_rails_env("production") do
      assert_equal({"Supervisor" => 1, "Dispatcher" => 1, "Worker" => 1, "Scheduler" => 1},
                   report["processes"]["expected"])
    end
  end

  test "without jobs there are no ages" do
    assert_equal({"ready" => {"count" => 0, "oldest_age" => nil},
                  "scheduled" => {"count" => 0, "overdue_age" => nil},
                  "claimed" => {"count" => 0, "oldest_age" => nil},
                  "failed" => {"count" => 0, "latest_at" => nil, "by_job_class" => {}, "by_exception_class" => {}}},
                 report["jobs"])
  end

  test "jobs waiting for a worker show how long the oldest has waited" do
    enqueue_job
    travel 90.seconds
    enqueue_job

    assert_equal({"count" => 2, "oldest_age" => 90}, report["jobs"]["ready"])
  end

  test "scheduled jobs show how long the most overdue one is past its time" do
    enqueue_job(scheduled_at: 1.minute.from_now)
    enqueue_job(scheduled_at: 2.minutes.from_now)
    enqueue_job(scheduled_at: 1.hour.from_now)

    assert_equal({"count" => 3, "overdue_age" => nil}, report["jobs"]["scheduled"])

    travel 3.minutes

    assert_equal({"count" => 3, "overdue_age" => 120}, report["jobs"]["scheduled"])
  end

  test "running jobs show how long the oldest has been running" do
    worker = register_process("Worker")
    enqueue_job
    SolidQueue::ReadyExecution.claim("*", 1, worker.id)
    # Solid Queue claims with the database's clock, which knows nothing of travel_to.
    SolidQueue::ClaimedExecution.sole.update!(created_at: 10.minutes.ago)

    assert_equal({"count" => 1, "oldest_age" => 600}, report["jobs"]["claimed"])
  end

  # The messages of the exceptions may hold personal data, mail addresses above
  # all, which has no place in the monitoring.
  test "failed jobs are counted by job and exception class, without their messages" do
    fail_job(enqueue_job(class_name: "ActionMailer::MailDeliveryJob"), Timeout::Error.new("erika@example.com"))
    fail_job(enqueue_job(class_name: "DsgvoCleanupJob"), ActiveRecord::Deadlocked.new)
    travel 1.hour
    fail_job(enqueue_job(class_name: "ActionMailer::MailDeliveryJob"), Timeout::Error.new("max@example.com"))

    failed = report["jobs"]["failed"]

    assert_equal 3, failed["count"]
    assert_equal "2026-11-11T09:15:00Z", failed["latest_at"]
    assert_equal({"ActionMailer::MailDeliveryJob" => 2, "DsgvoCleanupJob" => 1}, failed["by_job_class"])
    assert_equal({"Timeout::Error" => 2, "ActiveRecord::Deadlocked" => 1}, failed["by_exception_class"])
    assert_no_match(/example\.com/, JSON.generate(report))
  end

  # 08:15 UTC is 09:15 in Berlin, where the schedules are read.
  test "each recurring task shows when it was due, when it last ran and how that went" do
    yesterday = enqueue_job
    fail_job(yesterday, Timeout::Error.new)
    SolidQueue::RecurringExecution.create!(job: yesterday, task_key: "send_reminder_messages",
                                           run_at: Time.utc(2026, 11, 10, 5))
    today = enqueue_job
    finish_job(today)
    SolidQueue::RecurringExecution.create!(job: today, task_key: "send_reminder_messages",
                                           run_at: Time.utc(2026, 11, 11, 5))
    cleanup = enqueue_job(class_name: "DsgvoCleanupJob")
    fail_job(cleanup, ActiveRecord::Deadlocked.new)
    SolidQueue::RecurringExecution.create!(job: cleanup, task_key: "dsgvo_cleanup", run_at: Time.utc(2026, 11, 11, 4))

    with_rails_env("production") do
      assert_equal({"send_reminder_messages" => {"schedule" => "every day at 6am",
                                                 "last_due_at" => "2026-11-11T05:00:00Z",
                                                 "last_enqueued_at" => "2026-11-11T05:00:00Z",
                                                 "last_status" => "finished"},
                    "dsgvo_cleanup" => {"schedule" => "every day at 5am",
                                        "last_due_at" => "2026-11-11T04:00:00Z",
                                        "last_enqueued_at" => "2026-11-11T04:00:00Z",
                                        "last_status" => "failed"},
                    "clear_solid_queue_finished_jobs" => {"schedule" => "every hour at minute 12",
                                                          "last_due_at" => "2026-11-11T08:12:00Z",
                                                          "last_enqueued_at" => nil,
                                                          "last_status" => nil}},
                   report["recurring"])
    end
  end

  test "paused queues are listed" do
    SolidQueue::Pause.create!(queue_name: "default")

    assert_equal ["default"], report["paused_queues"]
  end

end
