require "erb"
require "tempfile"
require "tmpdir"

namespace :app do
  namespace :db do
    # Returns the database config of the given environment. Supports single and multi
    # database configs (the latter with the main database under "primary").
    database_config = lambda do |yaml, env|
      config = YAML.load(yaml, aliases: true).fetch(env)
      config.key?("database") ? config : config.fetch("primary")
    end

    # MySQL option file, so credentials never show up on a command line or in the logs
    mysql_option_file = lambda do |config|
      options = {
        host: config["host"], port: config["port"], socket: config["socket"],
        user: config["username"], password: config["password"]
      }.compact

      lines = options.map { |key, value| %(#{key}="#{value.to_s.gsub(/[\\"]/) { |char| "\\#{char}" }}") }
      ["[client]", *lines, ""].join("\n")
    end

    desc "Pull db from remote server and install locally (requires DB_ADAPTER=mysql)"
    task :pull do
      # All db servers read the same database, so the primary db server is sufficient
      server = primary(:db)
      raise "No server in role 'db' found" if server.nil?

      # Fail early if the local development database isn't MySQL
      local_db_config = database_config.(ERB.new(File.read("config/database.yml")).result, "development")
      unless %w[mysql2 trilogy].include?(local_db_config["adapter"])
        raise "Local development database must be MySQL (adapter: #{local_db_config['adapter']}). Run with DB_ADAPTER=mysql."
      end
      local_db_config = local_db_config.merge("host" => local_db_config["host"] || "localhost")

      # Setup variables
      dump_file_name   = "#{fetch(:application)}-#{Time.now.strftime("%Y%m%d-%H%M%S")}.dump"
      remote_dump_file = "/tmp/#{dump_file_name}"
      local_dump_dir   = Dir.mktmpdir
      local_dump_file  = File.join(local_dump_dir, dump_file_name)

      # Dump db on remote server and download it
      on(server) do
        # download! instead of capture: capture logs the output to log/capistrano.log
        db_config   = database_config.(download!("#{shared_path}/config/database.yml"), fetch(:rails_env))
        option_file = capture(:mktemp)

        begin
          upload!(StringIO.new(mysql_option_file.(db_config)), option_file, mode: 0o600)
          # umask: the dump must not be readable by other users on the server
          execute("umask 077 && mysqldump --defaults-extra-file=#{option_file} --column-statistics=0 -r #{remote_dump_file} #{db_config['database']}")
          download!(remote_dump_file, local_dump_file)
        ensure
          execute(:rm, "-f", option_file, remote_dump_file)
        end
      end

      # Restore dump locally
      run_locally do
        database = local_db_config["database"]

        Tempfile.create(["mysql-", ".cnf"]) do |option_file|
          option_file.write(mysql_option_file.(local_db_config))
          option_file.close
          mysql = "mysql --defaults-extra-file=#{option_file.path}"

          execute("#{mysql} -e \"DROP DATABASE IF EXISTS #{database}\"")
          execute("#{mysql} -e \"CREATE DATABASE #{database}\"")
          execute("#{mysql} #{database} < #{local_dump_file}")
        end
      end
    ensure
      FileUtils.rm_rf(local_dump_dir) if local_dump_dir
    end
  end
end
