require "application_system_test_case"

# A guest registers for an event in the modal of the offer page, without
# logging in; the login is offered at the top of the form.
class GuestRegistrationTest < ApplicationSystemTestCase

  include MailerRecords

  setup do
    @offer = create_offer
    @event = create_event(date_and_time: 1.week.from_now)
  end

  test "a guest registers through the modal" do
    visit frontend_offer_path(@offer)
    click_on "Jetzt anmelden"
    wait_for_transitions

    within ".modal" do
      assert_text "Haben Sie ein Bibliothekskonto?"
      assert_link "Mit Bibliothekskonto einloggen"

      fill_in "registration[first_name]", with: "Erika"
      fill_in "registration[last_name]", with: "Mustermann"
      fill_in "registration[email]", with: "erika@example.com"
      check "registration[gdrp_consent]"
      click_on "Verbindlich anmelden"
    end

    assert_text "Anmeldung erfolgreich"
    assert_predicate @event.registrations.sole, :origin_guest?
  end

end
