require "application_system_test_case"

# The forms for a new offer, a new event and a new or edited participant open
# as modals on top of their list and lead back to it.
class ModalFormsTest < ApplicationSystemTestCase

  include MailerRecords

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

  test "a new event from the global list: choose the course, continue, save" do
    offer = Offer.create!(title: "Literaturrecherche", type: "course")
    visit admin_events_path
    collect_script_errors

    click_on "Neuer Termin"

    assert_selector "input[type=search]:focus"
    select "Literaturrecherche", from: "offer_id"
    click_on "Weiter"

    assert_selector "#event_date_and_time"
    assert_selector ".modal", count: 1, visible: :all
    fill_in "event_date_and_time", with: 1.month.from_now.change(hour: 10)
    fill_in "event_max_no_of_participants", with: "12"
    click_on "Speichern"

    assert_text "Erfolgreich gespeichert."
    assert_current_path admin_events_path
    assert_equal 1, offer.events.count
    assert_no_selector ".modal, .modal-backdrop", visible: :all
    assert_empty script_errors
  end

  test "a mail preview stacks on the new event form and closes back to it" do
    offer = Offer.create!(title: "Literaturrecherche", type: "course")
    visit admin_offer_events_path(offer)
    collect_script_errors
    click_on "Neuer Termin"

    assert_selector "#event_date_and_time:focus"
    fill_in "event_date_and_time", with: 1.month.from_now.change(hour: 10)
    fill_in "event_participant_notes", with: "Bitte Laptop mitbringen"
    click_on "Vorschau Anmeldebestätigung"

    assert_selector ".modal.show", count: 2
    assert_text "Bitte Laptop mitbringen"
    # The preview and its backdrop lie above the form.
    assert evaluate_script(<<~JS)
      (() => {
        const [form, preview] = document.querySelectorAll(".modal.show")
        const backdrops = document.querySelectorAll(".modal-backdrop")
        const z = (element) => Number(getComputedStyle(element).zIndex)
        return backdrops.length === 2 && z(backdrops[1]) > z(form) && z(preview) > z(backdrops[1])
      })()
    JS

    # The preview takes the focus once it is fully open, so Escape closes it
    # and not the form below.
    assert_selector ".modal.show:focus", text: "Vorschau: E-Mail Anmeldebestätigung"
    send_keys :escape

    assert_selector ".modal.show", count: 1
    assert_selector ".modal-backdrop", count: 1
    assert_selector "body.modal-open"
    assert_equal "hidden", evaluate_script("document.body.style.overflow")
    assert_field "event_participant_notes", with: "Bitte Laptop mitbringen"

    send_keys :escape

    assert_no_selector ".modal, .modal-backdrop", visible: :all
    assert_no_selector "body.modal-open"
    assert_empty script_errors
  end

  test "a mail preview closed by its close button leaves the event form open" do
    offer = Offer.create!(title: "Literaturrecherche", type: "course")
    visit admin_offer_events_path(offer)
    collect_script_errors
    click_on "Neuer Termin"

    assert_selector "#event_date_and_time:focus"
    fill_in "event_date_and_time", with: 1.month.from_now.change(hour: 10)
    fill_in "event_participant_notes", with: "Bitte Laptop mitbringen"
    click_on "Vorschau Erinnerungsmail"

    # Bootstrap ignores a close before the preview is fully open.
    within(".modal.show:focus", text: "Vorschau: Erinnerungsmail") { find(".btn-close").click }

    assert_selector ".modal.show", count: 1
    assert_selector ".modal-backdrop", count: 1
    assert_selector "body.modal-open"
    assert_field "event_participant_notes", with: "Bitte Laptop mitbringen"
    assert_empty script_errors
  end

  test "a participant edited in the modal shows in the list" do
    @offer = create_offer
    @event = create_event
    create_registration
    visit admin_offer_event_registrations_path(@offer, @event)
    collect_script_errors

    open_participant_in_modal
    fill_in "registration_first_name", with: "Moritz"
    click_on "Speichern"

    assert_text "Erfolgreich gespeichert."
    assert_selector "td", text: "Moritz"
    assert_no_selector ".modal, .modal-backdrop", visible: :all
    assert_empty script_errors
  end

  test "a participant deleted in the modal leaves the list" do
    @offer = create_offer
    @event = create_event
    registration = create_registration
    visit admin_offer_event_registrations_path(@offer, @event)
    collect_script_errors

    open_participant_in_modal
    accept_confirm { click_on "Löschen" }

    assert_text "Erfolgreich gelöscht."
    assert_current_path admin_offer_event_registrations_path(@offer, @event)
    assert_no_selector "td", text: registration.email
    assert_no_selector ".modal, .modal-backdrop", visible: :all
    assert_empty script_errors
  end

  test "saving in the modal keeps the list where it was" do
    @offer = create_offer
    @event = create_event(max_no_of_participants: 0)
    40.times { |index| create_registration(email: "teilnehmer#{index}@example.com") }
    visit admin_offer_event_registrations_path(@offer, @event)
    execute_script("window.scrollTo(0, document.body.scrollHeight)")

    all("td.actions .dropdown-toggle").last.click
    click_on "Bearbeiten"

    assert_selector "#registration_first_name:focus"
    scrolled = evaluate_script("window.scrollY")

    assert_operator scrolled, :>, 0

    click_on "Speichern"

    assert_text "Erfolgreich gespeichert."
    assert_no_selector ".modal", visible: :all
    # The notice above makes the page taller; the browser keeps the rows in
    # view, so the position may only grow.
    assert_operator evaluate_script("window.scrollY"), :>=, scrolled
  end

  private

  def open_participant_in_modal
    find("td.actions .dropdown-toggle").click
    click_on "Bearbeiten"

    assert_selector "#registration_first_name:focus"
  end

end
