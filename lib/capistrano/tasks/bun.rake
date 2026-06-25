namespace :app do
  namespace :bun do

    desc "Install bun dependencies"
    task :install do
      on roles(:app, :web), in: :parallel do |host|
        within release_path do
          execute("cd #{release_path} && bun install")
        end
      end
    end

    desc "Run bun build"
    task :build do
      on roles(:app, :web), in: :parallel do |host|
        within release_path do
          execute("cd #{release_path} && bun run build")
        end
      end
    end

  end
end
