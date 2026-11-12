require "test_helper"

# The summary judges the facts of the report, so that the monitoring has a
# single status to read: ok, warning or error, for each check and, as the worst
# of them, for the whole. The facts stay in the report for finer checks.
class SolidQueueHealthSummaryTest < ActiveSupport::TestCase

  include SolidQueueRecords

  # The recurring tasks of production.
  RECURRING_TASKS = ["send_reminder_messages", "dsgvo_cleanup", "clear_solid_queue_finished_jobs"].freeze

  setup { travel_to Time.utc(2026, 11, 11, 8, 15) }

  def summary
    JSON.parse(JSON.generate(SolidQueueHealth.new.to_h))["summary"]
  end

  def check(name)
    summary["checks"][name]
  end

  # The processes the configuration of the test environment calls for, alive.
  def register_expected_processes
    ["Supervisor(fork)", "Dispatcher", "Worker"].each { register_process(it) }
  end

  test "a healthy queue is ok in every check" do
    register_expected_processes

    assert_equal({"status" => "ok", "message" => "all checks ok",
                  "checks" => {"processes" => {"status" => "ok", "message" => "3 of 3 processes alive"},
                               "ready_jobs" => {"status" => "ok", "message" => "0 waiting"},
                               "scheduled_jobs" => {"status" => "ok", "message" => "0 scheduled"},
                               "running_jobs" => {"status" => "ok", "message" => "0 running"},
                               "failed_jobs" => {"status" => "ok", "message" => "0 failed"},
                               "recurring_tasks" => {"status" => "ok", "message" => "0 of 0 on schedule"},
                               "paused_queues" => {"status" => "ok", "message" => "none paused"}}},
                 summary)
  end

  # Solid Queue counts a process as dead once its heartbeat is as old as the
  # threshold.
  test "a missing process is an error" do
    register_process("Supervisor(fork)")
    register_process("Dispatcher")
    register_process("Worker", last_heartbeat_at: 5.minutes.ago)

    assert_equal({"status" => "error", "message" => "Worker: 0 of 1 alive"}, check("processes"))
    assert_equal "error", summary["status"]
    assert_equal "processes: Worker: 0 of 1 alive", summary["message"]
  end

  test "more processes alive than expected are a warning" do
    register_expected_processes
    register_process("Supervisor(fork)", hostname: "app1")

    assert_equal({"status" => "warning", "message" => "Supervisor(fork): 2 alive, 1 expected"}, check("processes"))
  end

  test "a missing process outweighs a surplus one" do
    2.times { register_process("Supervisor(fork)") }
    register_process("Dispatcher")

    assert_equal({"status" => "error", "message" => "Worker: 0 of 1 alive, Supervisor(fork): 2 alive, 1 expected"},
                 check("processes"))
  end

  test "jobs waiting for 5 minutes are a warning, for 15 an error" do
    enqueue_job
    travel 299.seconds

    assert_equal({"status" => "ok", "message" => "1 waiting"}, check("ready_jobs"))

    travel 1.second

    assert_equal({"status" => "warning", "message" => "1 waiting, oldest for 5 min"}, check("ready_jobs"))

    travel 10.minutes

    assert_equal({"status" => "error", "message" => "1 waiting, oldest for 15 min"}, check("ready_jobs"))
  end

  test "a scheduled job overdue by a minute is a warning, by 5 an error" do
    enqueue_job(scheduled_at: 1.minute.from_now)
    travel 1.minute + 59.seconds

    assert_equal({"status" => "ok", "message" => "1 scheduled"}, check("scheduled_jobs"))

    travel 1.second

    assert_equal({"status" => "warning", "message" => "1 scheduled, oldest overdue by 1 min"}, check("scheduled_jobs"))

    travel 4.minutes

    assert_equal({"status" => "error", "message" => "1 scheduled, oldest overdue by 5 min"}, check("scheduled_jobs"))
  end

  test "a job running for 10 minutes is a warning, for 30 an error" do
    worker = register_process("Worker")
    enqueue_job
    SolidQueue::ReadyExecution.claim("*", 1, worker.id)
    # Solid Queue claims with the database's clock, which knows nothing of travel_to.
    SolidQueue::ClaimedExecution.sole.update!(created_at: Time.current)
    travel 599.seconds

    assert_equal({"status" => "ok", "message" => "1 running"}, check("running_jobs"))

    travel 1.second

    assert_equal({"status" => "warning", "message" => "1 running, oldest for 10 min"}, check("running_jobs"))

    travel 20.minutes

    assert_equal({"status" => "error", "message" => "1 running, oldest for 30 min"}, check("running_jobs"))
  end

  # A failed job is most likely a mail someone did not get. A warning that
  # passed by itself could pass over a weekend unseen.
  test "a failed job is a warning until someone deals with it" do
    fail_job(enqueue_job(class_name: "ActionMailer::MailDeliveryJob"), Timeout::Error.new)

    assert_equal({"status" => "warning", "message" => "1 failed (ActionMailer::MailDeliveryJob: 1)"},
                 check("failed_jobs"))

    travel 3.days

    assert_equal "warning", check("failed_jobs")["status"]

    SolidQueue::FailedExecution.sole.discard

    assert_equal({"status" => "ok", "message" => "0 failed"}, check("failed_jobs"))
  end

  # The reminders are due at 06:00 in Berlin, 05:00 UTC.
  test "a recurring task that has not run 10 minutes after its time is an error" do
    register_recurring_tasks(*RECURRING_TASKS, at: Time.utc(2026, 11, 1))
    run_recurring_task("send_reminder_messages", at: Time.utc(2026, 11, 10, 5))
    run_recurring_task("dsgvo_cleanup", at: Time.utc(2026, 11, 11, 4), class_name: "DsgvoCleanupJob")
    run_recurring_task("clear_solid_queue_finished_jobs", at: Time.utc(2026, 11, 11, 4, 12))

    with_rails_env("production") do
      travel_to Time.utc(2026, 11, 11, 5, 9, 59)

      assert_equal({"status" => "ok", "message" => "3 of 3 on schedule"}, check("recurring_tasks"))

      travel 1.second

      assert_equal({"status" => "error",
                    "message" => "send_reminder_messages missed its run due at 2026-11-11T05:00:00Z"},
                   check("recurring_tasks"))
    end
  end

  test "a recurring task whose last run failed is a warning" do
    run_recurring_task("send_reminder_messages", at: Time.utc(2026, 11, 11, 5), failed: true)
    run_recurring_task("dsgvo_cleanup", at: Time.utc(2026, 11, 11, 4), class_name: "DsgvoCleanupJob")
    run_recurring_task("clear_solid_queue_finished_jobs", at: Time.utc(2026, 11, 11, 8, 12))

    with_rails_env("production") do
      assert_equal({"status" => "warning", "message" => "send_reminder_messages failed in its last run"},
                   check("recurring_tasks"))
    end
  end

  # The hourly task was due at 08:12 and is still within its 10 minutes.
  test "a recurring task that never ran is an error, and outweighs a failed one" do
    register_recurring_tasks(*RECURRING_TASKS, at: Time.utc(2026, 11, 1))
    run_recurring_task("dsgvo_cleanup", at: Time.utc(2026, 11, 11, 4), failed: true, class_name: "DsgvoCleanupJob")

    with_rails_env("production") do
      assert_equal({"status" => "error",
                    "message" => "send_reminder_messages missed its run due at 2026-11-11T05:00:00Z, " \
                                 "dsgvo_cleanup failed in its last run"},
                   check("recurring_tasks"))
    end
  end

  # The scheduler runs a task from the next time after it registered it, as
  # on the first deployment or after a task was added; it does not catch up.
  # The daily tasks were due at 04:00 and 05:00, the hourly one at 08:12.
  test "a recurring task registered after its time has missed nothing until its next time" do
    register_recurring_tasks(*RECURRING_TASKS, at: Time.utc(2026, 11, 11, 8, 13))

    with_rails_env("production") do
      travel_to Time.utc(2026, 11, 11, 8, 25)

      assert_equal({"status" => "ok", "message" => "3 of 3 on schedule"}, check("recurring_tasks"))

      travel_to Time.utc(2026, 11, 11, 9, 22)

      assert_equal({"status" => "error",
                    "message" => "clear_solid_queue_finished_jobs missed its run due at 2026-11-11T09:12:00Z"},
                   check("recurring_tasks"))
    end
  end

  test "a recurring task the scheduler never registered has missed nothing, as no scheduler is alive" do
    register_expected_processes

    with_rails_env("production") do
      assert_equal({"status" => "ok", "message" => "3 of 3 on schedule"}, check("recurring_tasks"))
      assert_equal({"status" => "error", "message" => "Scheduler: 0 of 1 alive"}, check("processes"))
    end
  end

  test "a paused queue is a warning" do
    SolidQueue::Pause.create!(queue_name: "default")

    assert_equal({"status" => "warning", "message" => "paused: default"}, check("paused_queues"))
  end

  test "the whole takes the worst status and names every problem" do
    register_expected_processes
    SolidQueue::Pause.create!(queue_name: "default")
    fail_job(enqueue_job, Timeout::Error.new)

    assert_equal "warning", summary["status"]
    assert_equal "failed_jobs: 1 failed (SendReminderMessagesJob: 1); paused_queues: paused: default",
                 summary["message"]
  end

end
