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

  private

  def top_of(selector)
    evaluate_script("document.querySelector(#{selector.to_json}).getBoundingClientRect().top")
  end

  def bottom_of(selector)
    evaluate_script("document.querySelector(#{selector.to_json}).getBoundingClientRect().bottom")
  end

end
