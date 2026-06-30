class Offer < ApplicationRecord

  TYPES = %w[course consulting].freeze

  # `type` is a reserved word in Rails for Single Table Inheritance (STI).
  # We want type as a normal attribute, so we disable STI by setting the inheritance_column to nil.
  self.inheritance_column = nil

  # Relations
  has_and_belongs_to_many :topics, -> { order("position") } # rubocop:disable Rails/HasAndBelongsToMany
  has_and_belongs_to_many :target_groups, -> { order("position") } # rubocop:disable Rails/HasAndBelongsToMany
  has_many :events, dependent: :destroy
  has_many :upcoming_events, -> { upcoming.order(date_and_time: :asc) }, class_name: "Event", dependent: :destroy, inverse_of: :offer
  has_many :past_events, -> { past.order(date_and_time: :desc) }, class_name: "Event", dependent: :destroy, inverse_of: :offer

  # Validations
  validates :title, presence: true
  validates :type, inclusion: {in: TYPES}
  validates :email_from, format: {with: UPB_EMAIL_REGEXP}
  validates :contact_email, format: {with: UPB_EMAIL_REGEXP}

  # Scopes
  scope :published, -> { where(published: true) }
  scope :unpublished, -> { where(published: false) }
  scope :courses, -> { where(type: "course") }
  scope :consultings, -> { where(type: "consulting") }
  scope :archived, -> { where(archived: true) }
  scope :not_archived, -> { where(archived: false) }

  def course? = type == "course"

  def consulting? = type == "consulting"

end
