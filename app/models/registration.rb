class Registration < ApplicationRecord

  # So lange nach dem Termin bleiben die personenbezogenen Daten erhalten, bevor
  # app:dsgvo:cleanup die Anmeldung anonymisiert.
  RETENTION_PERIOD = 10.days

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
    [first_name, last_name].filter_map(&:presence).join(" ")
  end

  def full_name_reversed
    [last_name, first_name].filter_map(&:presence).join(", ")
  end

  def anonymized?
    first_name == "Gelöscht" || last_name == "Gelöscht" || email == "Gelöscht"
  end

  # Nur selbst angemeldete Personen haben ein Benutzerkonto, in dem sie die
  # Anmeldung wiederfinden. Im Admin angelegte und anonymisierte Anmeldungen
  # tragen keine ILS-ID.
  def account_linked?
    ils_primary_id.present?
  end

  # Der Tag, ab dem app:dsgvo:cleanup die Anmeldung anonymisiert.
  def deletion_date
    (event.date_and_time + RETENTION_PERIOD).to_date
  end

  # Eine Teilnahmebescheinigung gibt es erst, wenn der Termin vorbei ist und für
  # den Termin überhaupt eine Zertifizierung hinterlegt wurde. Für anonymisierte
  # Anmeldungen wäre die Bescheinigung wertlos, da der Name fehlt.
  def certificate_available?
    !anonymized? && event.certification.present? && event.past?
  end

end
