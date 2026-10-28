require "test_helper"

# The user of the frontend is no record: it is built from the Alma account at
# the login and kept in the session.
class UserTest < ActiveSupport::TestCase

  def alma_user(emails)
    {"primary_id" => "12345", "first_name" => "Erika", "last_name" => "Mustermann",
     "contact_info" => {"email" => emails}}
  end

  test "the preferred address of the Alma account is taken, else the first one" do
    preferred = alma_user([{"email_address" => "privat@example.com"},
                           {"email_address" => "erika@uni-paderborn.de", "preferred" => true}])
    unmarked = alma_user([{"email_address" => "privat@example.com"}, {"email_address" => "erika@uni-paderborn.de"}])

    assert_equal "erika@uni-paderborn.de", User.from_alma_user(preferred).email
    assert_equal "privat@example.com", User.from_alma_user(unmarked).email
    assert_nil User.from_alma_user(alma_user(nil)).email
  end

  test "a user survives the round trip through the session" do
    user = User.from_session(User.from_alma_user(alma_user([{"email_address" => "erika@example.com"}])).to_session)

    assert_equal ["12345", "Erika", "Mustermann", "erika@example.com"],
                 [user.ils_primary_id, user.first_name, user.last_name, user.email]
  end

  test "a session without a user id holds no user" do
    assert_nil User.from_session(nil)
    assert_nil User.from_session("12345")
    assert_nil User.from_session({"first_name" => "Erika"})
  end

end
