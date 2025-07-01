class TargetGroup < ApplicationRecord

  # Relations
  has_and_belongs_to_many :courses # rubocop:disable Rails/HasAndBelongsToMany
  has_and_belongs_to_many :consultings # rubocop:disable Rails/HasAndBelongsToMany

  # Validations
  validates :title, presence: true, uniqueness: true

  # List support
  acts_as_list

end
