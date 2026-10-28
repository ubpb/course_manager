require "application_system_test_case"

# The forms for a new offer, a new event and a new or edited participant open
# as modals on top of their list and lead back to it.
class ModalFormsTest < ApplicationSystemTestCase

  setup { log_in_admin }

  test "a new offer saved in the modal shows in the list" do
    visit admin_offers_path
    collect_script_errors

    click_on "Neues Angebot anlegen"

    assert_selector "#offer_title:focus"
    fill_in "offer_title", with: "Datenmanagement"
    click_on "Speichern"

    assert_text "Erfolgreich gespeichert."
    assert_link "Datenmanagement"
    assert_no_selector ".modal, .modal-backdrop", visible: :all
    assert_empty script_errors
  end

  test "the long offer form keeps its save button in view" do
    page.current_window.resize_to(1400, 700)
    visit admin_offers_path

    click_on "Neues Angebot anlegen"

    assert_selector "#offer_title:focus"
    assert evaluate_script(
      "document.querySelector('#offer-form .modal-footer').getBoundingClientRect().bottom <= window.innerHeight"
    )
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  # A long form would be lost to a stray click.
  test "a click beside a form modal leaves it open" do
    visit admin_offers_path
    click_on "Neues Angebot anlegen"

    assert_selector "#offer_title:focus"

    # Capybara counts the offsets from the center; this lands in the top left
    # corner of the modal, outside its dialog.
    modal = find(".modal")
    modal.click(x: 10 - (modal.rect.width / 2), y: 10 - (modal.rect.height / 2))
    wait_for_transitions

    assert_selector ".modal.show #offer-form"
  end

  test "a new event saved in the modal shows in the events of its course" do
    offer = Offer.create!(title: "Literaturrecherche", type: "course")
    visit admin_offer_events_path(offer)
    collect_script_errors

    click_on "Neuer Termin"

    assert_selector "#event_date_and_time:focus"
    fill_in "event_date_and_time", with: 1.month.from_now.change(hour: 10)
    fill_in "event_max_no_of_participants", with: "12"
    click_on "Speichern"

    assert_text "Erfolgreich gespeichert."
    assert_current_path admin_offer_events_path(offer)
    assert_equal 1, offer.events.count
    assert_no_selector ".modal, .modal-backdrop", visible: :all
    assert_empty script_errors
  end

end
