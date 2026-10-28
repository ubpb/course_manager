require "test_helper"

# The mails a test system delivers to letter_opener_web hold personal data, so
# only logged in admins get to read them.
module Admin
  class LetterOpenerTest < ActionDispatch::IntegrationTest

    # Temporarily: a permanent redirect would be cached by the browser and keep
    # sending the admin to the login after logging in.
    test "logged out visitors are sent to the admin login" do
      get "/admin/mail"

      assert_response :found
      assert_redirected_to new_admin_session_path
    end

    # In development the mails only exist on the developer's machine, so no login
    # gets in the way.
    test "locally the mails can be read without logging in" do
      Rails.env = "development"
      get "/admin/mail"

      assert_response :success
    ensure
      Rails.env = "test"
    end

    test "logged in admins can read the mails" do
      post admin_session_path, params: {login: {user_id: AlmaAuthenticationStub::VALID_USER_ID,
                                                password: AlmaAuthenticationStub::VALID_PASSWORD}}

      get "/admin/mail"

      assert_response :success
    end

  end
end
