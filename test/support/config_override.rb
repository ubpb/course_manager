# Replaces values of config/application.yml for the duration of a block, e.g.
# to switch on a feature flag:
#
#   with_config(locale_switching: {enabled: true}) { get root_path }
#
# Values set through environment variables still win (see ApplicationConfig).
module ConfigOverride

  def with_config(changes)
    original = ApplicationConfig.instance_variable_get(:@config)
    ApplicationConfig.configure(original.deep_merge(changes))
    yield
  ensure
    ApplicationConfig.configure(original)
  end

end
