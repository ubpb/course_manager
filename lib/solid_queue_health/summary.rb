class SolidQueueHealth
  # Judges the facts of a report, so that the monitoring has a single status to
  # read: each check gets ok, warning or error with a one-line message, the
  # whole the worst of them, with the messages of every check that is not ok.
  # Whoever needs other limits judges the facts in the report instead.
  class Summary

    STATUSES = ["ok", "warning", "error"].freeze

    # How old the oldest job of a kind may get before it warns or fails.
    AGE_LIMITS = {
      ready_jobs: {warning: 5.minutes, error: 15.minutes},
      scheduled_jobs: {warning: 1.minute, error: 5.minutes},
      running_jobs: {warning: 10.minutes, error: 30.minutes}
    }.freeze

    # How long after its time a recurring task may still be missing.
    RECURRING_GRACE = 10.minutes

    def initialize(report)
      @report = report
      @now = Time.iso8601(report[:generated_at])
    end

    def to_h
      ready, scheduled, claimed = jobs.values_at(:ready, :scheduled, :claimed)
      checks = {
        processes: processes,
        ready_jobs: age_check(:ready_jobs, ready[:oldest_age], "#{ready[:count]} waiting", "oldest for"),
        scheduled_jobs: age_check(:scheduled_jobs, scheduled[:overdue_age], "#{scheduled[:count]} scheduled",
                                  "oldest overdue by"),
        running_jobs: age_check(:running_jobs, claimed[:oldest_age], "#{claimed[:count]} running", "oldest for"),
        failed_jobs: failed_jobs,
        recurring_tasks: recurring_tasks,
        paused_queues: paused_queues
      }
      {status: checks.values.pluck(:status).max_by { STATUSES.index(it) }, message: message(checks), checks: checks}
    end

    private

    def message(checks)
      problems = checks.reject { |_, check| check[:status] == "ok" }
      return "all checks ok" if problems.empty?

      problems.map { |name, check| "#{name}: #{check[:message]}" }.join("; ")
    end

    def jobs
      @report[:jobs]
    end

    # A process is alive while its heartbeat is younger than the threshold,
    # as Solid Queue sees it.
    def processes
      expected = @report[:processes][:expected]
      threshold = @report[:processes][:alive_threshold]
      alive = @report[:processes][:registered].select { it[:heartbeat_age] < threshold }.pluck(:kind).tally

      missing = expected.filter_map do |kind, count|
        "#{kind}: #{alive.fetch(kind, 0)} of #{count} alive" if alive.fetch(kind, 0) < count
      end
      surplus = alive.filter_map do |kind, count|
        "#{kind}: #{count} alive, #{expected.fetch(kind, 0)} expected" if count > expected.fetch(kind, 0)
      end

      if missing.any? || surplus.any?
        result(missing.any? ? "error" : "warning", (missing + surplus).join(", "))
      else
        result("ok", "#{expected.values.sum} of #{expected.values.sum} processes alive")
      end
    end

    # The message names the age in whole minutes once it counts.
    def age_check(name, age, message, age_label)
      limits = AGE_LIMITS.fetch(name)
      return result("ok", message) if age.nil? || age < limits[:warning]

      result(age < limits[:error] ? "warning" : "error", "#{message}, #{age_label} #{age / 60} min")
    end

    def failed_jobs
      failed = jobs[:failed]
      return result("ok", "0 failed") if failed[:count].zero?

      classes = failed[:by_job_class].map { |name, count| "#{name}: #{count}" }.join(", ")
      result("warning", "#{failed[:count]} failed (#{classes})")
    end

    def recurring_tasks
      tasks = @report[:recurring]
      missed = tasks.filter_map { |key, task| "#{key} missed its run due at #{task[:last_due_at]}" if missed?(task) }
      failed = tasks.filter_map { |key, task| "#{key} failed in its last run" if task[:last_status] == :failed }

      if missed.any? || failed.any?
        result(missed.any? ? "error" : "warning", (missed + failed).join(", "))
      else
        result("ok", "#{tasks.size} of #{tasks.size} on schedule")
      end
    end

    # The scheduler records each run at the time it was due. It runs a task
    # from the next time after it registered it and does not catch up, so a
    # run due before, as on the first deployment, was not missed. A task it
    # never registered has no scheduler, which the processes check reports.
    def missed?(task)
      due_at = Time.iso8601(task[:last_due_at])
      return false if @now - due_at < RECURRING_GRACE
      return false if task[:registered_at].nil? || Time.iso8601(task[:registered_at]) >= due_at

      task[:last_enqueued_at].nil? || Time.iso8601(task[:last_enqueued_at]) < due_at
    end

    def paused_queues
      paused = @report[:paused_queues]
      paused.any? ? result("warning", "paused: #{paused.join(", ")}") : result("ok", "none paused")
    end

    def result(status, message)
      {status: status, message: message}
    end

  end
end
