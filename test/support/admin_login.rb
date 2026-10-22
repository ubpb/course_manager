# Signs in to the admin area through the stubbed Alma login (see
# AlmaAuthenticationStub), as the admin integration tests need it.
module AdminLogin

  def log_in_admin
    post admin_session_path, params: {login: {user_id: AlmaAuthenticationStub::VALID_USER_ID,
                                              password: AlmaAuthenticationStub::VALID_PASSWORD}}
  end

end
