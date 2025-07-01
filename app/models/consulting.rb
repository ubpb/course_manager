class Consulting < ApplicationRecord

  # Relations
  belongs_to :category, optional: true
  has_and_belongs_to_many :topics, -> { order("position") } # rubocop:disable Rails/HasAndBelongsToMany
  has_and_belongs_to_many :target_groups, -> { order("position") } # rubocop:disable Rails/HasAndBelongsToMany

  # Validations
  validates :title, presence: true
  validates :contact_name, presence: true
  validates :contact_email, format: {with: /\A[^@\s]+@[^@\s]+\z/}, presence: true

  # Scopes
  scope :published, -> { where(published: true) }
  scope :unpublished, -> { where(published: false) }

end
