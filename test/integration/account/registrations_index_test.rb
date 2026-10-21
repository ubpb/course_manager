require "test_helper"

# The overview only lists the registrations with their event details. Every
# option -- cancelling, the certificate, the access link -- lives on the detail
# page, which opens as a modal right from the list.
class Account::RegistrationsIndexTest < ActionDispatch::IntegrationTest

  setup do
    @offer = Offer.create!(title: "Literaturrecherche", type: "course", published: true)
    @upcoming_event = @offer.events.create!(date_and_time: 1.week.from_now, duration: 90, location: "Raum 1.2",
                                            max_no_of_participants: 10)
    @past_event = @offer.events.create!(date_and_time: 3.days.ago, duration: 60, online: true,
                                        max_no_of_participants: 10)
    Certification.create!(event: @past_event, learning_results: "Katalogrecherche", signature: "Max Muster")

    @upcoming = register(@upcoming_event)
    @past = register(@past_event)
  end

  def register(event)
    event.registrations.create!(first_name: "Erika", last_name: "Mustermann", email: "erika@example.com",
                                ils_primary_id: AlmaAuthenticationStub::VALID_USER_ID)
  end

  def log_in
    post session_path, params: {login: {user_id: AlmaAuthenticationStub::VALID_USER_ID,
                                        password: AlmaAuthenticationStub::VALID_PASSWORD}}
  end

  test "each registration shows its event details" do
    log_in
    get account_root_path

    assert_response :success
    assert_includes response.body, "90 Minuten"
    assert_includes response.body, "Raum 1.2"
    assert_includes response.body, "60 Minuten"
    assert_not_includes response.body, "Anmeldung erforderlich"
    assert_not_includes response.body, "translation missing"
  end

  test "each registration opens its detail page as a modal" do
    log_in
    get account_root_path

    [@upcoming, @past].each do |registration|
      assert_select "a[href=?][data-turbo-stream]", account_registration_path(registration, modal: 1), text: /Details/
    end
    assert_select "#registration-modal"
  end

  test "cancelling and the certificate are left to the detail page" do
    log_in
    get account_root_path

    assert_select "form[action=?]", account_registration_path(@upcoming), count: 0
    assert_select "a[href=?]", certificate_account_registration_path(@past), count: 0
  end

end
