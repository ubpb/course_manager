# Builds the state of Solid Queue the way its processes leave it: jobs in their
# executions, registered processes with their heartbeats, runs of recurring
# tasks.
module SolidQueueRecords

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

  # A run of a recurring task as the scheduler records it, at the time it was
  # due, whose job then finished or failed.
  def run_recurring_task(key, at:, failed: false, class_name: "SendReminderMessagesJob")
    job = enqueue_job(class_name: class_name)
    failed ? fail_job(job, Timeout::Error.new) : finish_job(job)
    SolidQueue::RecurringExecution.create!(job: job, task_key: key, run_at: at)
  end

  # Recurring tasks as the scheduler registers them when it first starts with
  # them in its configuration. Only the time counts; the report reads the
  # schedules from the configuration.
  def register_recurring_tasks(*keys, at:)
    keys.each { SolidQueue::RecurringTask.create!(key: it, schedule: "every hour", command: "nil", created_at: at) }
  end

  def register_process(kind, **attributes)
    SolidQueue::Process.create!(kind: kind, name: "#{kind.downcase}-#{SecureRandom.hex(4)}", pid: 4711,
                                hostname: "batch", last_heartbeat_at: Time.current, **attributes)
  end

  # Solid Queue reads the configuration of the current environment; only
  # production has recurring tasks.
  def with_rails_env(name)
    original = Rails.env
    Rails.env = name
    yield
  ensure
    Rails.env = original
  end

end
