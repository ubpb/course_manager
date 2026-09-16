class ApplicationRecord < ActiveRecord::Base

  # Blank, or an address at uni-paderborn.de (optionally a subdomain like ub.).
  # The local part stays narrow on purpose: the address ends up in a From header,
  # where a comma or an angle bracket would break the addressing.
  UPB_EMAIL_REGEXP = /\A(?:|[a-z0-9._%+-]+@(?:[a-z0-9-]+\.)*uni-paderborn\.de)\z/i

  primary_abstract_class

  # Strip attributes
  strip_attributes collapse_spaces: true

end
