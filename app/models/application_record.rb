class ApplicationRecord < ActiveRecord::Base

  UPB_EMAIL_REGEXP = /\A^$|([^@\s]+)@ub.uni-paderborn.de\z/i

  primary_abstract_class

  # Strip attributes
  strip_attributes collapse_spaces: true

end
