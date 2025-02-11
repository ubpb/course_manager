class ApplicationRecord < ActiveRecord::Base

  primary_abstract_class

  # Strip attributes
  strip_attributes collapse_spaces: true

end
