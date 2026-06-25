class Course < ApplicationRecord

  # Relations
  has_and_belongs_to_many :topics, -> { order("position") } # rubocop:disable Rails/HasAndBelongsToMany
  has_and_belongs_to_many :target_groups, -> { order("position") } # rubocop:disable Rails/HasAndBelongsToMany
  has_many :events, dependent: :destroy

  # Validations
  validates :title, presence: true
  validates :email_from, format: {with: UPB_EMAIL_REGEXP}

  # Scopes
  scope :published, -> { where(published: true) }
  scope :unpublished, -> { where(published: false) }

end
