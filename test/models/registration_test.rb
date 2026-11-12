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

  test "a registration knows how it came about" do
    registration = Registration.new(origin: :guest)

    assert_predicate registration, :origin_guest?
    assert_not_predicate registration, :origin_admin?
  end

  test "an unknown origin is refused" do
    assert_predicate Registration.new(origin: "phone").tap(&:validate).errors[:origin], :present?
  end

  # Registrations anonymized before the origin was recorded keep it unknown.
  test "the origin may be unknown" do
    assert_empty Registration.new(origin: nil).tap(&:validate).errors[:origin]
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

  # Registering oneself refuses the second; staff in the admin may still enter
  # it, so the validation lives in the context of the front end.
  test "the same email address registers only once for an event" do
    event = create_event
    event.registrations.create!(first_name: "Erika", last_name: "Mustermann", email: "erika@example.com")
    second = event.registrations.build(first_name: "Erika", last_name: "Mustermann", email: "Erika@Example.com",
                                       gdrp_consent: true)

    assert_not second.valid?(:user_registration)
    assert_equal [Registration::DUPLICATE_EMAIL], second.errors[:email]
    assert_predicate second, :valid?
  end

  test "the same email address may register for another event" do
    create_event.registrations.create!(first_name: "Erika", last_name: "Mustermann", email: "erika@example.com")
    other = create_event.registrations.build(first_name: "Erika", last_name: "Mustermann", email: "erika@example.com",
                                             gdrp_consent: true)

    assert other.valid?(:user_registration)
  end

  test "a registration counts as attended until marked as a no-show" do
    assert_not_predicate Registration.new, :no_show?
  end

  test "a no-show gets no certificate" do
    event = create_event
    event.update!(date_and_time: 2.days.ago)
    Certification.create!(event: event, learning_results: "Katalogrecherche")
    registration = event.registrations.create!(first_name: "A", last_name: "B", email: "a@example.com")

    assert_predicate registration, :certificate_available?

    registration.no_show = true

    assert_not_predicate registration, :certificate_available?
  end

end
