class Migration::Testing::ApplicationRecord < ActiveRecord::Base

  self.abstract_class = true

  # Only the reading role here, a writing connection is not created
  connects_to database: {reading: :migration_testing_database}

  # Tells Rails to use the :reading role as the default
  def self.default_role
    :reading
  end

  # To throw ReadOnly exception instead of cryptic "No connection pool" if trying to write
  def readonly?
    true
  end

end
