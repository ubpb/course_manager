class Certificate < ApplicationRecord

  # Relations
  belongs_to :registration, optional: true

  # Validations
  validates :digest, presence: true
  validates :initials, presence: true

end
