require "test_helper"
require "rake"

# The cron task now sends a reminder to every participant, so what matters most
# is that nobody is ever mailed twice.
class SendReminderMessagesTest < ActiveSupport::TestCase

  TASK = "app:mailer:send_reminder_messages"

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?(TASK)

    @offer = Offer.create!(title: "Literaturrecherche", type: "course", published: true)
    @event = create_event(2.days.from_now)

    ActionMailer::Base.deliveries.clear
  end

  def create_event(date_and_time)
    @offer.events.create!(date_and_time: date_and_time,
                          location: "Raum 1.2",
                          max_no_of_participants: 10,
                          registration_required: true,
                          published: true)
  end

  def register(event, first_name, email)
    event.registrations.create!(first_name: first_name, last_name: "Mustermann", email: email)
  end

  def run_task
    Rake::Task[TASK].reenable
    Rake::Task[TASK].invoke
  end

  def recipients
    ActionMailer::Base.deliveries.flat_map(&:to)
  end

  # ActionMailer builds its class level mailer methods through method_missing,
  # so there is nothing for Minitest's stub to alias -- define the singleton for
  # the duration of the block instead.
  def with_failing_delivery(&block)
    Admin::Mailers::EventsMailer.define_singleton_method(:reminder_message) do |registration, **_options|
      block&.call(registration)
      raise "Mailserver nicht erreichbar"
    end

    capture_io { run_task }.last
  ensure
    Admin::Mailers::EventsMailer.singleton_class.send(:remove_method, :reminder_message)
  end

  test "every participant of an upcoming event is reminded" do
    register(@event, "Max", "max@example.com")
    register(@event, "Erika", "erika@example.com")

    run_task

    assert_equal ["erika@example.com", "max@example.com"], recipients.sort
  end

  test "a second run does not remind anybody a second time" do
    register(@event, "Max", "max@example.com")

    run_task
    ActionMailer::Base.deliveries.clear
    run_task

    assert_empty recipients
  end

  test "a participant reminded from the admin is not reminded again by the task" do
    registration = register(@event, "Max", "max@example.com")
    registration.update!(reminder_message_sent_at: 1.hour.ago)

    run_task

    assert_empty recipients
  end

  test "the send is recorded on the registration" do
    registration = register(@event, "Max", "max@example.com")

    run_task

    assert_not_nil registration.reload.reminder_message_sent_at
  end

  test "a participant registering after a run is picked up by the next one" do
    register(@event, "Max", "max@example.com")
    run_task
    ActionMailer::Base.deliveries.clear

    register(@event, "Erika", "erika@example.com")
    run_task

    assert_equal ["erika@example.com"], recipients
  end

  test "events outside the three day window are left alone" do
    register(create_event(5.days.from_now), "Max", "max@example.com")
    register(create_event(1.hour.ago), "Erika", "erika@example.com")

    run_task

    assert_empty recipients
  end

  test "a failed delivery releases the claim and is retried by the next run" do
    registration = register(@event, "Max", "max@example.com")

    stderr = with_failing_delivery

    assert_empty recipients
    assert_includes stderr, "Erinnerungsmail an Anmeldung ##{registration.id} fehlgeschlagen"
    assert_nil registration.reload.reminder_message_sent_at

    run_task

    assert_equal ["max@example.com"], recipients
  end

  test "a failed delivery does not release a reminder sent from the admin meanwhile" do
    registration = register(@event, "Max", "max@example.com")
    sent_from_admin = 2.minutes.from_now

    with_failing_delivery do |claimed_registration|
      Registration.where(id: claimed_registration.id).update_all(reminder_message_sent_at: sent_from_admin)
    end

    assert_in_delta sent_from_admin, registration.reload.reminder_message_sent_at, 1.second
  end

  test "anonymized registrations are skipped and stay unclaimed" do
    registration = register(@event, "Max", "max@example.com")
    registration.update_columns(first_name: "Gelöscht", last_name: "Gelöscht", email: "Gelöscht")

    run_task

    assert_empty recipients
    assert_nil registration.reload.reminder_message_sent_at
  end

end
