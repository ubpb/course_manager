namespace :app do
  namespace :jobs do
    # For the monitoring (see SolidQueueHealth). Production logs to standard
    # output, so while the report is gathered whatever else is written there
    # goes to standard error, and standard output carries the JSON alone.
    desc "Print the state of Solid Queue as JSON, for monitoring"
    task health: :environment do
      report = $stdout.dup
      $stdout.reopen($stderr)
      report.puts JSON.pretty_generate(SolidQueueHealth.new.to_h)
    ensure
      if report
        $stdout.reopen(report)
        report.close
      end
    end
  end
end
