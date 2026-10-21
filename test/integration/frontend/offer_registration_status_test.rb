require "test_helper"

# On the public offer page a registered participant is pointed to the detail
# page of the registration, which carries the access link and everything else.
class Frontend::OfferRegistrationStatusTest < ActionDispatch::IntegrationTest

  setup do
    @offer = Offer.create!(title: "Literaturrecherche", type: "course", published: true)
    @event = @offer.events.create!(date_and_time: 1.week.from_now,
                                   online: true,
                                   online_url: "https://meet.example.com/abc",
                                   max_no_of_participants: 10,
                                   registration_required: true,
                                   published: true)
  end

  def log_in
    post session_path, params: {login: {user_id: AlmaAuthenticationStub::VALID_USER_ID,
                                        password: AlmaAuthenticationStub::VALID_PASSWORD}}
  end

  test "a registered participant is led to the detail page, not to the access link" do
    registration = @event.registrations.create!(first_name: "Erika", last_name: "Mustermann",
                                                email: "erika@example.com",
                                                ils_primary_id: AlmaAuthenticationStub::VALID_USER_ID)

    log_in
    get frontend_offer_path(@offer)

    assert_response :success
    assert_select "a[href=?]", account_registration_path(registration), text: /Sie sind bereits angemeldet/
    assert_not_includes response.body, "meet.example.com"
  end

  test "someone not registered gets the registration button" do
    log_in
    get frontend_offer_path(@offer)

    assert_response :success
    assert_select "a", text: "Jetzt anmelden"
    assert_not_includes response.body, "meet.example.com"
  end

end
