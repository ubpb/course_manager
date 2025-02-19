class Course < ApplicationRecord

  EMAIL_REGEX = /\A^$|([^@\s]+)@ub.uni-paderborn.de\z/i

  # Relations
  belongs_to :category, optional: true
  has_and_belongs_to_many :topics, -> { order("position") } # rubocop:disable Rails/HasAndBelongsToMany
  has_and_belongs_to_many :target_groups, -> { order("position") } # rubocop:disable Rails/HasAndBelongsToMany
  has_many :events, dependent: :destroy

  # Validations
  validates :title, presence: true
  validates :email_from, format: {with: EMAIL_REGEX}

  # Scopes
  scope :published, -> { where(published: true) }

end
