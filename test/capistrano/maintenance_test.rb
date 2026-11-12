require "test_helper"
require "open3"

# The maintenance mode of a stage: while a flag file exists in the shared
# directory, nginx answers every request with public/maintenance.html. The
# tasks set, remove and look for that flag. They run as a dry run here, which
# prints the commands without connecting to a server.
class MaintenanceTest < ActiveSupport::TestCase

  FLAG = "/ubpb/course_manager/shared/public/system/MAINTENANCE_ON".freeze

  def dry_run(task)
    output, status = Open3.capture2e("bundle", "exec", "cap", "testing", task, "--dry-run", chdir: Rails.root)

    assert_predicate status, :success?, output
    output
  end

  test "switching it on creates the flag in the shared directory" do
    output = dry_run("app:maintenance:on")

    assert_includes output, "mkdir -p /ubpb/course_manager/shared/public/system"
    assert_includes output, "touch #{FLAG}"
  end

  test "switching it off removes the flag" do
    assert_includes dry_run("app:maintenance:off"), "rm -f #{FLAG}"
  end

  test "the status names each web server" do
    assert_match(/stage\.ub\.upb\.de: maintenance mode is (on|off)/, dry_run("app:maintenance:status"))
  end

end
