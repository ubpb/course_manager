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
  validates :contact_email, format: {with: UPB_EMAIL_REGEXP}

  # Callbacks
  before_save :nullify_default_contact_info

  # Scopes
  scope :published, -> { where(published: true) }
  scope :unpublished, -> { where(published: false) }
  scope :courses, -> { where(type: "course") }
  scope :consultings, -> { where(type: "consulting") }
  scope :archived, -> { where(archived: true) }
  scope :not_archived, -> { where(archived: false) }

  def course? = type == "course"

  def consulting? = type == "consulting"

  def contact_info?
    true # always true, because we always have a contact (either the default or a custom one)
  end

  def contact_name
    super.presence || default_contact_name
  end

  def contact_email
    super.presence || default_contact_email
  end

  def contact_phone
    super.presence || default_contact_phone
  end

  def default_contact_name = ApplicationConfig[:default_contact, :name, default: "Schulungsteam"]

  def default_contact_email = ApplicationConfig[:default_contact, :email, default: "schulung@ub.uni-paderborn.de"]

  def default_contact_phone = ApplicationConfig[:default_contact, :phone, default: "05251 60-2017"]

  private

  # Only persist contact info that differs from the current default, so the DB holds
  # genuine overrides and defaults keep flowing live from config.
  def nullify_default_contact_info
    self[:contact_name] = nil if self[:contact_name].to_s == default_contact_name
    self[:contact_email] = nil if self[:contact_email].to_s == default_contact_email
    self[:contact_phone] = nil if self[:contact_phone].to_s == default_contact_phone
  end

end
