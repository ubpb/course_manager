# Replaces values of config/application.yml for the duration of a block, e.g.
# to switch on a feature flag:
#
#   with_config(locale_switching: {enabled: true}) { get root_path }
#
# Environment variables that would override a replaced value (see
# ApplicationConfig) are hidden for the block, so the test does not depend on
# the machine it runs on.
module ConfigOverride

  def with_config(changes)
    original = ApplicationConfig.instance_variable_get(:@config)
    hidden = overriding_env_names(changes).index_with { ENV.delete(it) }
    ApplicationConfig.configure(original.deep_merge(changes))
    yield
  ensure
    ApplicationConfig.configure(original)
    hidden&.each { |name, value| ENV[name] = value if value }
  end

  private

  def overriding_env_names(changes, path = [])
    changes.flat_map do |key, value|
      value.is_a?(Hash) ? overriding_env_names(value, path + [key]) : (path + [key]).join("_").upcase
    end
  end

end
