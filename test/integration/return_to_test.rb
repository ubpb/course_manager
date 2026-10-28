require "test_helper"

# A page that needs a login remembers where the visitor wanted to go, but only
# a page to look at.
class ReturnToTest < ActionDispatch::IntegrationTest

  include MailerRecords

  test "the account remembers itself as the way back" do
    get account_root_path

    assert_redirected_to new_session_path
    assert_equal account_root_path, session[:return_to]
  end

  test "a form sent while logged out is not remembered" do
    @offer = create_offer
    @event = create_event(date_and_time: 1.week.from_now)

    post frontend_event_registrations_path(@event), params: {registration: {first_name: "Erika"}}

    assert_redirected_to new_session_path
    assert_nil session[:return_to]
  end

end
