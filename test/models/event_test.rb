require "test_helper"

class EventTest < ActiveSupport::TestCase

  include MailerRecords

  setup do
    @offer = create_offer
    @event = create_event
  end

  test "registration_for finds the registration of the logged in user" do
    registration = create_registration(ils_primary_id: "12345")
    create_registration(ils_primary_id: "99999", email: "other@example.com")

    assert_equal registration, @event.registration_for(User.new(ils_primary_id: "12345"))
  end

  test "registration_for is nil for someone not registered and for nobody logged in" do
    create_registration(ils_primary_id: "99999")

    assert_nil @event.registration_for(User.new(ils_primary_id: "12345"))
    assert_nil @event.registration_for(nil)
  end

end
