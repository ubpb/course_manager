# Session-only user for the frontend. Not backed by a database table —
# authenticated against the Alma API and serialized into the session.
class User

  attr_reader :ils_primary_id, :first_name, :last_name, :email

  def initialize(ils_primary_id:, first_name: nil, last_name: nil, email: nil)
    @ils_primary_id = ils_primary_id
    @first_name = first_name
    @last_name = last_name
    @email = email
  end

  def self.from_alma_user(alma_user)
    new(
      ils_primary_id: alma_user["primary_id"],
      first_name: alma_user["first_name"],
      last_name: alma_user["last_name"],
      email: preferred_email(alma_user)
    )
  end

  def self.from_session(data)
    return nil unless data.is_a?(Hash) && data["ils_primary_id"].present?

    new(
      ils_primary_id: data["ils_primary_id"],
      first_name: data["first_name"],
      last_name: data["last_name"],
      email: data["email"]
    )
  end

  def self.preferred_email(alma_user)
    emails = Array(alma_user.dig("contact_info", "email"))
    email = emails.find { |e| e["preferred"] } || emails.first
    email&.dig("email_address")
  end
  private_class_method :preferred_email

  # Session data is serialized to JSON, so use string keys throughout.
  def to_session
    {
      "ils_primary_id" => ils_primary_id,
      "first_name" => first_name,
      "last_name" => last_name,
      "email" => email
    }
  end

  def full_name
    [first_name, last_name].map(&:presence).compact.join(" ")
  end

end
