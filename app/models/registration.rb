class Registration < ApplicationRecord

  # Relations
  belongs_to :event, counter_cache: true
  has_many :certificates, dependent: :nullify

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true, format: {with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i}
  validates :gdrp_consent, acceptance: {accept: true}, on: :user_registration

  def full_name_reversed
    [first_name, last_name].map(&:presence).compact.join(", ")
  end

end
