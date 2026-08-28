ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

Dir[Rails.root.join("test/support/**/*.rb")].each { |file| require file }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # The login rate limiters count per IP in the shared cache. Without this a
    # test that exhausts a limit would throttle whatever runs after it.
    setup { Rails.cache.clear }

    # Add more helper methods to be used by all tests here...
  end
end
