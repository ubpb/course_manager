class MigrationRecord < ActiveRecord::Base

  self.abstract_class = true
  connects_to database: {reading: :migration}  # only the reading role here, a writing connection is not created

  def self.default_role # tells Rails to use the :reading role as the default
    :reading
  end

  def readonly? # to throw ReadOnly exception instead of cryptic "No connection pool" if trying to write
    true
  end

end
