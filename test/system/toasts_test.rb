require "application_system_test_case"

# The admin shows its flash messages as toasts at the top right, below the
# navigation bar. They float over the page, so they show at any scroll
# position and move nothing.
class ToastsTest < ApplicationSystemTestCase

  include MailerRecords

  setup { log_in_admin }

  test "a toast floats below the navigation bar and moves nothing" do
    create_offer
    create_offer(title: "Publikationsberatung", type: "consulting")
    visit admin_offers_path
    card_top = top_of("main .card")

    first("input[name='bulk_process_ids[]']").click
    select "Archivieren", from: "bulk_process_action"
    click_on "Ausführen"

    assert_selector "#admin-toasts .toast", text: "Angebot(e) wurde archiviert"
    assert_operator top_of("#admin-toasts .toast"), :>=, bottom_of("#admin-navbar")
    assert_equal card_top, top_of("main .card")
  end

  test "a toast stays in view at the top of the window when the page is scrolled" do
    @offer = create_offer
    40.times { |index| create_event(date_and_time: (index + 1).days.from_now) }
    visit admin_events_path

    select "In anderes Angebot verschieben", from: "bulk_process_action"
    click_on "Ausführen"

    assert_selector "#admin-toasts .toast", text: "Bitte mindestens einen Termin auswählen"

    execute_script("window.scrollTo(0, document.body.scrollHeight)")

    assert_operator evaluate_script("window.scrollY"), :>, 0
    assert_operator top_of("#admin-toasts .toast"), :<, 30
  end

  test "a success toast hides by itself after a few seconds" do
    create_offer
    visit admin_offers_path
    collect_script_errors

    archive_first_offer

    assert_selector "#admin-toasts .toast", text: "Angebot(e) wurde archiviert"
    using_wait_time(7) { assert_no_selector "#admin-toasts .toast", visible: :all }
    assert_empty script_errors
  end

  test "a warning toast stays until it is closed" do
    move_without_selection

    assert_selector "#admin-toasts .toast", text: "Bitte mindestens einen Termin auswählen"
    # Longer than a success toast would stay.
    sleep 6

    assert_selector "#admin-toasts .toast", text: "Bitte mindestens einen Termin auswählen"

    find("#admin-toasts .btn-close").click

    assert_no_selector "#admin-toasts .toast", visible: :all
    assert_empty script_errors
  end

  test "a toast does not come back with Back" do
    move_without_selection

    assert_selector "#admin-toasts .toast", text: "Bitte mindestens einen Termin auswählen"

    click_on "Angebote", match: :first

    assert_current_path admin_offers_path

    go_back

    assert_current_path admin_events_path
    assert_no_selector "#admin-toasts .toast", visible: :all
    assert_empty script_errors
  end

  private

  def archive_first_offer
    first("input[name='bulk_process_ids[]']").click
    select "Archivieren", from: "bulk_process_action"
    click_on "Ausführen"
  end

  def move_without_selection
    @offer = create_offer
    create_event(date_and_time: 1.week.from_now)
    visit admin_events_path

    collect_script_errors
    select "In anderes Angebot verschieben", from: "bulk_process_action"
    click_on "Ausführen"
  end

  def top_of(selector)
    evaluate_script("document.querySelector(#{selector.to_json}).getBoundingClientRect().top")
  end

  def bottom_of(selector)
    evaluate_script("document.querySelector(#{selector.to_json}).getBoundingClientRect().bottom")
  end

end
