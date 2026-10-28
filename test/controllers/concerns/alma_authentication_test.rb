require "test_helper"

# The two Alma calls behind both logins: the password check and the lookup of
# the user. The controller tests stub them out (AlmaAuthenticationStub), so
# they are checked here against a fake client.
class AlmaAuthenticationTest < ActiveSupport::TestCase

  include ConfigOverride

  # Answers like the Alma API: a LogicalError for a wrong password or an
  # unknown user, the user record otherwise.
  class FakeClient

    attr_reader :requests

    def initialize(users)
      @users = users
      @requests = []
    end

    def post(url, params:)
      @requests << [:post, url]
      password = @users.dig(url.delete_prefix("users/"), :password)
      raise AlmaApi::LogicalError.new("Failed to authenticate user", "401652") if password != params[:password]
    end

    def get(url)
      @requests << [:get, url]
      record = @users.dig(url.delete_prefix("users/"), :record)
      raise AlmaApi::LogicalError.new("User not found", "401861") if record.nil?

      record
    end

  end

  class Login

    include AlmaAuthentication

    public :alma_client, :authenticate_against_alma, :fetch_alma_user

  end

  setup do
    @client = FakeClient.new("max%40uni" => {password: "geheim", record: {"primary_id" => "max@uni"}})
    @login = Login.new
    @login.instance_variable_set(:@alma_client, @client)
  end

  test "the client uses the configured API key" do
    with_config(alma_api: {api_key: "test-key"}) do
      assert_equal "test-key", Login.new.alma_client.configuration.api_key
    end
  end

  test "the right password passes, a wrong one or an unknown user does not" do
    assert @login.authenticate_against_alma("max@uni", "geheim")
    assert_not @login.authenticate_against_alma("max@uni", "falsch")
    assert_not @login.authenticate_against_alma("erika@uni", "geheim")
  end

  test "the user is looked up, an unknown one is nil" do
    assert_equal({"primary_id" => "max@uni"}, @login.fetch_alma_user("max@uni"))
    assert_nil @login.fetch_alma_user("erika@uni")
  end

  # The controllers tell a failed login from an unreachable Alma.
  test "an unreachable Alma is not taken for a wrong password" do
    def @client.post(*, **) = raise(AlmaApi::GatewayError.new("Service unavailable", "GENERAL_ERROR"))
    def @client.get(*) = raise(AlmaApi::ServerError.new("Internal error", "SERVER_ERROR"))

    assert_raises(AlmaApi::GatewayError) { @login.authenticate_against_alma("max@uni", "geheim") }
    assert_raises(AlmaApi::ServerError) { @login.fetch_alma_user("max@uni") }
  end

  test "the user id is escaped in the URL" do
    @login.authenticate_against_alma("max@uni", "geheim")
    @login.fetch_alma_user("../max")

    assert_equal [[:post, "users/max%40uni"], [:get, "users/..%2Fmax"]], @client.requests
  end

end
