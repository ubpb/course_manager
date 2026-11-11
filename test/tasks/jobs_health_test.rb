require "test_helper"
require "rake"

# The monitoring runs the task and reads its standard output as JSON. In
# production the log goes to standard output too, so the task moves whatever
# else is written there over to standard error.
class JobsHealthTest < ActiveSupport::TestCase

  TASK = "app:jobs:health".freeze

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?(TASK)
  end

  # Runs the task with a log on standard output, as in production, and returns
  # what went to standard output and to standard error.
  def run_task_logging_to_stdout
    Dir.mktmpdir do |dir|
      out_path = File.join(dir, "stdout")
      err_path = File.join(dir, "stderr")
      begin
        original = [$stdout, $stderr]
        $stdout = File.open(out_path, "w")
        $stderr = File.open(err_path, "w")
        log = ActiveSupport::Logger.new($stdout)
        Rails.logger.broadcast_to(log)
        Rake::Task[TASK].reenable
        Rake::Task[TASK].invoke
      ensure
        Rails.logger.stop_broadcasting_to(log)
        [$stdout, $stderr].each(&:close)
        $stdout = original.first
        $stderr = original.last
      end
      [File.read(out_path), File.read(err_path)]
    end
  end

  test "standard output carries the report alone, log lines go to standard error" do
    out, err = run_task_logging_to_stdout

    assert_equal "course_manager", JSON.parse(out)["app"]
    assert_match "SELECT", err
  end

end
