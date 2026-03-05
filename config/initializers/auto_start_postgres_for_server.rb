# Auto-start local PostgreSQL when booting Rails server in development.
# Disable by setting AUTO_START_POSTGRES=0.
if Rails.env.development? && defined?(Rails::Server) && ENV.fetch("AUTO_START_POSTGRES", "1") != "0"
  require "open3"

  module AutoStartPostgresForServer
    module_function

    def call
      return if postgres_ready?
      return unless docker_compose_available?

      puts "[db] PostgreSQL not reachable, running: docker compose up -d postgres"

      success = system("docker", "compose", "up", "-d", "postgres", chdir: Rails.root.to_s)
      return unless success

      wait_for_postgres!
    rescue StandardError => e
      warn "[db] Auto-start postgres failed: #{e.message}"
    end

    def postgres_ready?
      host = ENV.fetch("DB_HOST", "127.0.0.1")
      port = ENV.fetch("DB_PORT", "5432")
      user = ENV.fetch("DB_USERNAME", "postgres")

      _stdout, _stderr, status = Open3.capture3(
        "pg_isready", "-h", host, "-p", port.to_s, "-U", user
      )
      status.success?
    end

    def docker_compose_available?
      _stdout, _stderr, status = Open3.capture3("docker", "compose", "version")
      status.success?
    end

    def wait_for_postgres!
      attempts = 20

      attempts.times do
        return if postgres_ready?

        sleep 1
      end

      warn "[db] PostgreSQL did not become ready after docker compose startup"
    end
  end

  AutoStartPostgresForServer.call
end
