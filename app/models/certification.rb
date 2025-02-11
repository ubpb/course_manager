class Certification < ApplicationRecord

  # Relations
  belongs_to :event

  # Validations
  validates :learning_results, presence: true

end
