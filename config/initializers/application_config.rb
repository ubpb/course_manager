#
# Small helper class to access the application configuration from anywhere in the application
# with support for default values.
#
# Usage: ApplicationConfig[:key, :subkey, default: "default value"]
#
class ApplicationConfig

  class << self

    def configure(config)
      @config = config
    end

    def [](*params, default: nil)
      env_value = ENV[params.join("_").upcase].presence
      value = @config&.dig(*params).presence

      env_value || value || default
    end

  end

end

ApplicationConfig.configure(Rails.application.config_for(:application))
