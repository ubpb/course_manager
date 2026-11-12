# The state of Solid Queue for the monitoring, which reads it as JSON from
# `bin/rails app:jobs:health`: the processes the configuration calls for and
# those that sent heartbeats, the jobs by state, and the recurring tasks with
# their registration and last run. A summary up front judges these facts (see Summary); the
# facts stay for finer checks.
#
# Times are given in UTC, ages in seconds. The messages of failed jobs stay
# out, since they may hold personal data; their exception classes are enough
# to tell the failures apart.
class SolidQueueHealth

  def initialize
    @now = Time.current
    @configuration = SolidQueue::Configuration.new
  end

  def to_h
    facts = {
      app: Rails.application.class.module_parent_name.underscore,
      environment: Rails.env,
      generated_at: timestamp(@now),
      processes: processes,
      jobs: jobs,
      recurring: recurring,
      paused_queues: SolidQueue::Pause.order(:queue_name).pluck(:queue_name)
    }

    {summary: Summary.new(facts).to_h, **facts}
  end

  private

  def processes
    {
      expected: expected_processes,
      alive_threshold: SolidQueue.process_alive_threshold.to_i,
      registered: SolidQueue::Process.order(:kind, :hostname, :pid).map do |process|
        {kind: process.kind, hostname: process.hostname, pid: process.pid,
         last_heartbeat_at: timestamp(process.last_heartbeat_at), heartbeat_age: age(process.last_heartbeat_at)}
      end
    }
  end

  # The supervisor starts one process per configured dispatcher and scheduler
  # and per worker process. It registers itself under a kind that names its
  # mode, such as "Supervisor(fork)".
  def expected_processes
    {"Supervisor(#{@configuration.mode})" => 1}.merge(configured_processes.map { it.kind.to_s.camelize }.tally)
  end

  def jobs
    {
      ready: {count: SolidQueue::ReadyExecution.count,
              oldest_age: age(SolidQueue::ReadyExecution.minimum(:created_at))},
      scheduled: {count: SolidQueue::ScheduledExecution.count,
                  overdue_age: age(SolidQueue::ScheduledExecution.where(scheduled_at: ..@now).minimum(:scheduled_at))},
      claimed: {count: SolidQueue::ClaimedExecution.count,
                oldest_age: age(SolidQueue::ClaimedExecution.minimum(:created_at))},
      failed: failed_jobs
    }
  end

  def failed_jobs
    {
      count: SolidQueue::FailedExecution.count,
      latest_at: timestamp(SolidQueue::FailedExecution.maximum(:created_at)),
      by_job_class: SolidQueue::FailedExecution.joins(:job).group(:class_name).count,
      by_exception_class: SolidQueue::FailedExecution.pluck(:error).pluck("exception_class").tally
    }
  end

  # The scheduler registers a task when it first starts with it in its
  # configuration, and keeps that time when it starts again.
  def recurring
    registered_at = SolidQueue::RecurringTask.pluck(:key, :created_at).to_h

    recurring_tasks.to_h do |task|
      last_run = SolidQueue::RecurringExecution.where(task_key: task.key).order(run_at: :desc).first

      [task.key, {schedule: task.schedule,
                  registered_at: timestamp(registered_at[task.key]),
                  last_due_at: timestamp(task.previous_time),
                  last_enqueued_at: timestamp(last_run&.run_at),
                  last_status: last_run&.job&.status}]
    end
  end

  def recurring_tasks
    configured_processes.select { it.kind == :scheduler }.flat_map { it.attributes[:recurring_tasks] }
  end

  def configured_processes
    @configured_processes ||= @configuration.configured_processes
  end

  def timestamp(time)
    time&.utc&.iso8601
  end

  def age(time)
    time && (@now - time).round
  end

end
