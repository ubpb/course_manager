require "test_helper"

# The detail page in the account gathers everything about one registration --
# the date, the custom text of the confirmation, what the offer is about -- so
# participants find it again long after the confirmation mail is gone.
class Account::RegistrationShowTest < ActionDispatch::IntegrationTest

  setup do
    @offer = Offer.create!(title: "Literaturrecherche",
                           type: "course",
                           published: true,
                           description: "Wir **suchen** Literatur.",
                           learning_targets: "- Kataloge nutzen")
    @event = @offer.events.create!(date_and_time: 1.week.from_now,
                                   duration: 90,
                                   online: true,
                                   online_url: "https://meet.example.com/abc",
                                   max_no_of_participants: 10,
                                   registration_required: true,
                                   published: true,
                                   confirmation_message: "###ANREDE###, bitte Zotero installieren.")
    @registration = create_registration(@event, ils_primary_id: AlmaAuthenticationStub::VALID_USER_ID,
                                                user_notes: "Komme etwas später",
                                                internal_notes: "Intern: VIP")
  end

  def create_registration(event, **attributes)
    event.registrations.create!({first_name: "Max", last_name: "Mustermann", email: "max@example.com"}.merge(attributes))
  end

  def log_in
    post session_path, params: {login: {user_id: AlmaAuthenticationStub::VALID_USER_ID,
                                        password: AlmaAuthenticationStub::VALID_PASSWORD}}
  end

  def cancel_form_selector
    "form[action='#{account_registration_path(@registration)}']"
  end

  test "the participant sees everything about the registration" do
    log_in
    get account_registration_path(@registration)

    assert_response :success
    assert_includes response.body, "Literaturrecherche"
    assert_includes response.body, "Hallo Max Mustermann, bitte Zotero installieren."
    assert_includes response.body, "<strong>suchen</strong>"
    assert_includes response.body, "Kataloge nutzen"
    assert_includes response.body, "90 Minuten"
    assert_includes response.body, "href=\"https://meet.example.com/abc\""
    assert_includes response.body, "Komme etwas später"
    assert_not_includes response.body, "Intern: VIP"
    assert_not_includes response.body, "translation missing"
    assert_select cancel_form_selector
  end

  test "an unpublished and archived offer is still shown" do
    @offer.update!(published: false, archived: true)
    @event.update!(published: false)

    log_in
    get account_registration_path(@registration)

    assert_response :success
    assert_select "a[href=?]", frontend_offer_path(@offer), count: 0
  end

  test "a published offer links to its public page" do
    log_in
    get account_registration_path(@registration)

    assert_select "a[href=?]", frontend_offer_path(@offer)
  end

  test "someone else's registration is not found" do
    other = create_registration(@event, ils_primary_id: "99999")

    log_in
    get account_registration_path(other)

    assert_response :not_found
  end

  test "a registration without an account is not found" do
    manual = create_registration(@event, ils_primary_id: nil)

    log_in
    get account_registration_path(manual)

    assert_response :not_found
  end

  test "a logged out visitor is sent to the login and back" do
    get account_registration_path(@registration)

    assert_redirected_to new_session_path
    assert_equal account_registration_path(@registration), session[:return_to]

    log_in

    assert_redirected_to account_registration_path(@registration)
  end

  test "a past event offers the certificate instead of cancelling" do
    @event.update!(date_and_time: 3.days.ago)
    Certification.create!(event: @event, learning_results: "Katalogrecherche", signature: "Max Muster")

    log_in
    get account_registration_path(@registration)

    assert_response :success
    assert_select cancel_form_selector, count: 0
    assert_not_includes response.body, "meet.example.com"
    assert_select "a[href=?]", certificate_account_registration_path(@registration)
    assert_not_includes response.body, "translation missing"
  end

  # Event#upcoming? counts the whole day, and so does the cancellation itself.
  test "an event earlier today can still be cancelled" do
    @event.update!(date_and_time: Time.zone.now.beginning_of_day + 1.minute)

    log_in
    get account_registration_path(@registration)

    assert_select cancel_form_selector
  end

  test "without a custom text there is no notes box" do
    @event.update!(confirmation_message: nil, location: nil, duration: nil)

    log_in
    get account_registration_path(@registration)

    assert_response :success
    assert_select ".callout-warning", count: 0
  end

  # The text is kept for plain text mails, so the page must not render more of
  # it than the mail would.
  test "the custom text is escaped" do
    @event.update!(confirmation_message: "<script>alert(1)</script>")

    log_in
    get account_registration_path(@registration)

    assert_not_includes response.body, "<script>alert(1)"
    assert_includes response.body, "&lt;script&gt;alert(1)"
  end

  test "the overview links each registration to its detail page" do
    past_event = @offer.events.create!(date_and_time: 3.days.ago, max_no_of_participants: 10)
    past = create_registration(past_event, ils_primary_id: AlmaAuthenticationStub::VALID_USER_ID)

    log_in
    get account_root_path

    assert_select "a[href=?]", account_registration_path(@registration)
    assert_select "a[href=?]", account_registration_path(past)
  end

end
