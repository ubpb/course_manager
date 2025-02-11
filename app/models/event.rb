class Event < ApplicationRecord

  # Relations
  belongs_to :course
  has_many :registrations, dependent: :destroy
  has_one :report, dependent: :destroy
  has_one :certification, dependent: :destroy

  # Validations
  validates :date_and_time, presence: true
  validates :duration, numericality: {only_integer: true, greater_than_or_equal_to: 0}, allow_nil: true
  validates :max_no_of_participants, numericality: {only_integer: true, greater_than_or_equal_to: 0}

  # Scopes
  scope :published, -> { where(published: true) }
  scope :with_report, -> { includes(:report).where.not(reports: {id: nil}) }
  scope :without_report, -> { includes(:report).where(reports: {id: nil}) }
  scope :upcoming, -> { where("date_and_time >= ?", Time.zone.today.beginning_of_day) }
  scope :past, -> { where("date_and_time < ?", Time.zone.today.beginning_of_day) }
  scope :online, -> { where(online: true) }

  def upcoming?
    date_and_time >= Time.zone.today.beginning_of_day
  end

  def past?
    date_and_time < Time.zone.today.beginning_of_day
  end

  def limited?
    max_no_of_participants.positive?
  end

  def no_of_free_spaces
    if limited?
      spaces_count = max_no_of_participants - registrations_count
      spaces_count.negative? ? 0 : spaces_count
    else
      -1
    end
  end

  def full?
    limited? && registrations_count >= max_no_of_participants
  end

end
