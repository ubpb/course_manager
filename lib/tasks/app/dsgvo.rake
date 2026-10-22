namespace :app do
  namespace :dsgvo do

    desc "Cleanup personal information to be GDRP compliant"
    task cleanup: :environment do
      DsgvoCleanupJob.perform_now
    end

  end
end
