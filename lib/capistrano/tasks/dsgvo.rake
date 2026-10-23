namespace :app do
  namespace :dsgvo do
    # Runs `bin/rails app:dsgvo:anonymize_all` on the database server of a stage
    # and refuses the production stage. With the jobs service stopped meanwhile,
    # no queued job runs before it is dropped:
    #
    #   cap testing app:jobs:stop
    #   cap testing app:dsgvo:anonymize_all
    #   cap testing app:jobs:start
    desc "Anonymize all registrations on a stage (refuses the production stage)"
    task :anonymize_all do
      abort "app:dsgvo:anonymize_all refuses the production stage." if fetch(:stage).to_s == "production"

      on primary(:db) do
        within current_path do
          with rails_env: fetch(:rails_env) do
            database = capture(:bundle, :exec, "bin/rails", "runner",
                               "'print ActiveRecord::Base.connection_db_config.database'")
            execute :bundle, :exec, "bin/rails", "app:dsgvo:anonymize_all", "CONFIRM=#{database}"
          end
        end
      end
    end
  end
end
