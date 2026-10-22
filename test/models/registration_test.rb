require "test_helper"

class RegistrationTest < ActiveSupport::TestCase

  test "a registration with an ILS id is linked to an account" do
    assert_predicate Registration.new(ils_primary_id: "12345"), :account_linked?
  end

  # Registrations staff enter in the admin, and those anonymized after the
  # event, carry no ILS id: there is no account to point them to.
  test "a registration without an ILS id is not linked" do
    assert_not_predicate Registration.new(ils_primary_id: nil), :account_linked?
    assert_not_predicate Registration.new(ils_primary_id: ""), :account_linked?
  end

  test "personal data is kept for ten days after the event" do
    assert_equal 10.days, Registration::RETENTION_PERIOD

    event = Event.new(date_and_time: Time.zone.parse("2026-10-15 18:00"))

    assert_equal Date.new(2026, 10, 25), Registration.new(event: event).deletion_date
  end

  def create_event
    offer = Offer.create!(title: "T", type: "course")
    offer.events.create!(date_and_time: 1.week.from_now, max_no_of_participants: 10)
  end

  # The validation alone cannot stop two requests saving at the same moment.
  test "the database refuses a second registration of one account for an event" do
    event = create_event
    row = {event_id: event.id, first_name: "A", last_name: "B", email: "a@example.com",
           ils_primary_id: "12345", created_at: Time.current, updated_at: Time.current}

    Registration.insert_all!([row])
    assert_raises(ActiveRecord::RecordNotUnique) do
      Registration.insert_all!([row])
    end
  end

  test "registrations without an account may repeat" do
    event = create_event

    2.times { event.registrations.create!(first_name: "A", last_name: "B", email: "a@example.com") }

    assert_equal 2, event.registrations.count
  end

end
