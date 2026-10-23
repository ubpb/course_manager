require "test_helper"

# The mails a test system delivers to letter_opener_web hold personal data, so
# only logged in admins get to read them.
module Admin
  class LetterOpenerTest < ActionDispatch::IntegrationTest

    test "logged out visitors are sent to the admin login" do
      get "/admin/letter_opener"

      assert_redirected_to new_admin_session_path
    end

    test "logged in admins can read the mails" do
      post admin_session_path, params: {login: {user_id: AlmaAuthenticationStub::VALID_USER_ID,
                                                password: AlmaAuthenticationStub::VALID_PASSWORD}}

      get "/admin/letter_opener"

      assert_response :success
    end

  end
end
