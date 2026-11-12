# Maintenance mode: while the flag file exists, nginx answers every request
# with 503 and public/maintenance.html. The flag lives in shared/public/system,
# a linked dir, so it survives deploys until the mode is switched off again.
#
# nginx on every server with the role :web needs, at server level after `root`:
#
#   if (-f $document_root/system/MAINTENANCE_ON) {
#     return 503;
#   }
#   error_page 503 @maintenance;
#   location @maintenance {
#     rewrite ^ /maintenance.html break;
#   }
#
#   cap <stage> app:maintenance:on | app:maintenance:off | app:maintenance:status
namespace :app do
  namespace :maintenance do
    flag_dir = -> { shared_path.join("public", "system") }
    flag = -> { flag_dir.call.join("MAINTENANCE_ON") }

    desc "Switch the maintenance mode on: nginx answers every request with public/maintenance.html"
    task :on do
      on roles(:web) do
        execute :mkdir, "-p", flag_dir.call
        execute :touch, flag.call
      end
    end

    desc "Switch the maintenance mode off"
    task :off do
      on roles(:web) do
        execute :rm, "-f", flag.call
      end
    end

    desc "Show whether the maintenance mode is on, per web server"
    task :status do
      on roles(:web) do |host|
        state = test("[ -f #{flag.call} ]") ? "on" : "off"
        puts "#{host}: maintenance mode is #{state}"
      end
    end
  end
end
