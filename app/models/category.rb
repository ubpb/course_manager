class Category < ApplicationRecord

  # Relations
  has_many :courses, dependent: :nullify

  # Validations
  validates :title, presence: true
  validates :color_code, presence: true

  # List support
  acts_as_list

end
