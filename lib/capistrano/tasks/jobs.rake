require "erb"

# Solid Queue (bin/jobs: workers, dispatcher and the scheduler for the recurring
# tasks in config/recurring.yml) runs as the systemd *user* service
# course_manager-jobs of the deploy user, on the servers with the role :jobs.
# Give that role to exactly one server per stage, or the recurring tasks run
# more than once.
#
# Once per server, as root, so the service runs without an open login session:
#
#   loginctl enable-linger <deploy user>
#
# Every deploy checks the configuration before publishing, then installs the
# unit file and restarts the service. By hand:
#
#   cap <stage> app:jobs:status | app:jobs:restart | app:jobs:stop | app:jobs:start
#   journalctl --user -u course_manager-jobs   (on the server)
namespace :app do
  namespace :jobs do
    service = "course_manager-jobs"
    unit_file = ".config/systemd/user/#{service}.service" # relative to the home directory
    template = File.expand_path("../templates/jobs.service.erb", __dir__)

    # systemctl --user needs the user's runtime directory, which a
    # non-interactive SSH session doesn't always have set.
    systemctl = ->(*args) { "XDG_RUNTIME_DIR=/run/user/$(id -u) systemctl --user #{args.join(" ")}" }

    desc "Check the Solid Queue configuration of the new release"
    task :check do
      on roles(:jobs) do
        within release_path do
          with rails_env: fetch(:rails_env) do
            execute :bundle, :exec, "bin/jobs", "check"
          end
        end
      end
    end

    desc "Install (or update) the systemd user unit and enable it"
    task :install do
      unit = ERB.new(File.read(template)).result_with_hash(
        stage: fetch(:stage),
        current_path: current_path,
        rails_env: fetch(:rails_env),
        ruby_version: fetch(:rvm_ruby_version)
      )

      on roles(:jobs) do
        execute :mkdir, "-p", File.dirname(unit_file)
        upload! StringIO.new(unit), unit_file
        execute systemctl.("daemon-reload")
        execute systemctl.("enable", service)
      end
    end

    %w[start stop restart].each do |command|
      desc "#{command.capitalize} the Solid Queue service"
      task command do
        on roles(:jobs) do
          execute systemctl.(command, service)
        end
      end
    end

    desc "Show the status of the Solid Queue service"
    task :status do
      on roles(:jobs) do
        puts capture(systemctl.("status", service, "--no-pager"), raise_on_non_zero_exit: false)
      end
    end
  end
end
