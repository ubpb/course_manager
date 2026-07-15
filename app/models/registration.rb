class Registration < ApplicationRecord

  # Relations
  belongs_to :event, counter_cache: true
  has_many :certificates, dependent: :nullify

  # Scopes
  scope :for_ils_user, ->(ils_primary_id) { where(ils_primary_id: ils_primary_id) }

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true, format: {with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i}
  validates :gdrp_consent, acceptance: {accept: true}, on: :user_registration
  validates :ils_primary_id, uniqueness: {scope: :event_id}, allow_nil: true, on: :user_registration

  def full_name
    [first_name, last_name].map(&:presence).compact.join(" ")
  end

  def full_name_reversed
    [last_name, first_name].map(&:presence).compact.join(", ")
  end

  def anonymized?
    first_name == "Gelöscht" || last_name == "Gelöscht" || email == "Gelöscht"
  end

end
