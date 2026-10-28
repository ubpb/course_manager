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

  test "free spaces are counted down to zero, an unlimited event has -1" do
    @event.max_no_of_participants = 2
    @event.registrations_count = 1

    assert_equal 1, @event.no_of_free_spaces
    assert_not_predicate @event, :full?

    # Staff may add participants beyond the limit by hand.
    @event.registrations_count = 3

    assert_equal 0, @event.no_of_free_spaces
    assert_predicate @event, :full?

    @event.max_no_of_participants = 0

    assert_equal(-1, @event.no_of_free_spaces)
    assert_not_predicate @event, :full?
  end

  test "registration closes when the event is full or takes place today" do
    @event.date_and_time = 1.week.from_now

    assert_not_predicate @event, :registration_closed?

    @event.registrations_count = @event.max_no_of_participants

    assert_predicate @event, :registration_closed?

    @event.registrations_count = 0
    @event.date_and_time = Time.zone.now.end_of_day - 1.minute

    assert_predicate @event, :registration_closed?
  end

  test "a change concerns the participants by date, kind, and the place that applies" do
    event = Event.find(@event.id)

    event.max_no_of_participants = 20

    assert_not_predicate event, :reportable_changes?

    event.online_url = "https://meet.example.com/neu"

    assert_not_predicate event, :reportable_changes?, "the link of an event on site does not matter"

    event.location = "Raum 2.1"

    assert_predicate event, :reportable_changes?

    event = Event.find(@event.id)
    event.online = true

    assert_predicate event, :reportable_changes?

    @event.update!(online: true)
    event = Event.find(@event.id)
    event.location = "Raum 2.1"

    assert_not_predicate event, :reportable_changes?, "the place of an online event does not matter"

    event.online_url = "https://meet.example.com/neu"

    assert_predicate event, :reportable_changes?
  end

end
