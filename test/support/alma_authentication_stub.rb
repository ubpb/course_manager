# Stubs out the Alma round trip of both login controllers, so that a login can
# be driven from a test without talking to the API.
module AlmaAuthenticationStub

  VALID_USER_ID = "12345"
  VALID_PASSWORD = "secret"

  def authenticate_against_alma(user_id, password)
    user_id == VALID_USER_ID && password == VALID_PASSWORD
  end

  def fetch_alma_user(user_id)
    return nil unless user_id == VALID_USER_ID

    {
      "primary_id" => VALID_USER_ID,
      "first_name" => "Erika",
      "last_name" => "Mustermann",
      "record_type" => {"value" => "STAFF"},
      "status" => {"value" => "ACTIVE"},
      "contact_info" => {"email" => [{"preferred" => true, "email_address" => "erika@example.com"}]}
    }
  end

end

SessionsController.prepend(AlmaAuthenticationStub)
Admin::SessionsController.prepend(AlmaAuthenticationStub)
