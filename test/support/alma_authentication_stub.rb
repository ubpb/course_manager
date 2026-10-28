# Stubs out the Alma round trip of both login controllers, so that a login can
# be driven from a test without talking to the API.
module AlmaAuthenticationStub

  VALID_USER_ID = "12345".freeze
  VALID_PASSWORD = "secret".freeze
  # A library user who is not staff, and a staff member whose account has
  # expired. Both log in with VALID_PASSWORD.
  PATRON_USER_ID = "23456".freeze
  INACTIVE_USER_ID = "34567".freeze

  USERS = {
    VALID_USER_ID => {record_type: "STAFF", status: "ACTIVE"},
    PATRON_USER_ID => {record_type: "PUBLIC", status: "ACTIVE"},
    INACTIVE_USER_ID => {record_type: "STAFF", status: "INACTIVE"}
  }.freeze

  def authenticate_against_alma(user_id, password) # rubocop:disable Naming/PredicateMethod -- the name of the stubbed method
    USERS.key?(user_id) && password == VALID_PASSWORD
  end

  def fetch_alma_user(user_id)
    user = USERS[user_id] || return

    {
      "primary_id" => user_id,
      "first_name" => "Erika",
      "last_name" => "Mustermann",
      "record_type" => {"value" => user[:record_type]},
      "status" => {"value" => user[:status]},
      "contact_info" => {"email" => [{"preferred" => true, "email_address" => "erika@example.com"}]}
    }
  end

end

SessionsController.prepend(AlmaAuthenticationStub)
Admin::SessionsController.prepend(AlmaAuthenticationStub)
