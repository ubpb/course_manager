class Offer < ApplicationRecord

  TYPES = %w[course consulting self_study_course].freeze

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
  validates :call_to_action_url, format: {with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true}

  # Callbacks
  before_save :nullify_default_values

  # Scopes
  scope :published, -> { where(published: true) }
  scope :unpublished, -> { where(published: false) }
  scope :courses, -> { where(type: "course") }
  scope :consultings, -> { where(type: "consulting") }
  scope :self_study_courses, -> { where(type: "self_study_course") }
  scope :archived, -> { where(archived: true) }
  scope :not_archived, -> { where(archived: false) }

  def course? = type == "course"

  def consulting? = type == "consulting"

  def self_study_course? = type == "self_study_course"

  # SEO friendly URLs: /angebote/42-recherche-in-datenbanken
  #
  # The ID stays in front, so `Offer.find(params[:id])` keeps working
  # ("42-recherche-in-datenbanken".to_i == 42) and old, slug-less URLs
  # remain valid. The slug is purely cosmetic and may change with the title.
  def to_param
    slug = title.to_s.parameterize(locale: :de).truncate(70, separator: "-", omission: "")
    slug.blank? ? id.to_s : "#{id}-#{slug}"
  end

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

  def default_call_to_action_text = ApplicationConfig[:default_call_to_action, :text, default: "Selbstlernkurs öffnen"]

  def call_to_action_text
    super.presence || default_call_to_action_text
  end

  def call_to_action?
    call_to_action_url.present?
  end

  private

  # Only persist values that differs from the current default, so the DB holds
  # genuine overrides and defaults keep flowing live from config.
  def nullify_default_values
    # Contact info
    self[:contact_name] = nil if self[:contact_name].to_s == default_contact_name
    self[:contact_email] = nil if self[:contact_email].to_s == default_contact_email
    self[:contact_phone] = nil if self[:contact_phone].to_s == default_contact_phone

    # Call to action
    self[:call_to_action_text] = nil if self[:call_to_action_text].to_s == default_call_to_action_text
  end

end
