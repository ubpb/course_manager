require "application_system_test_case"

# The menu bar of the admin leads back to the page last seen in another area,
# each tab on its own, while the link of the current area leads to its list.
# Staff switch to the events and back to the offer they were working on.
class AdminNavigationTest < ApplicationSystemTestCase

  include MailerRecords

  setup do
    @offer = create_offer(title: "Publikationsberatung", type: "consulting")

    log_in_admin
  end

  test "the menu leads back to the page last seen in an area" do
    visit edit_admin_offer_path(@offer)
    collect_script_errors

    click_menu "Termine"

    assert_current_path admin_events_path

    click_menu "Angebote"

    assert_current_path edit_admin_offer_path(@offer)
    assert_empty script_errors
  end

  test "the link of the current area leads to its list" do
    visit edit_admin_offer_path(@offer)

    click_menu "Angebote"

    assert_current_path admin_offers_path
  end

  test "an event opened from its course comes back in the offer context" do
    @offer = create_offer
    event = create_event
    visit admin_offer_event_registrations_path(@offer, event, nav_scope: "offer")

    click_menu "Termine"
    click_menu "Angebote"

    assert_current_path admin_offer_event_registrations_path(@offer, event, nav_scope: "offer")
  end

  test "each tab leads back to its own pages" do
    other = create_offer(title: "Schreibberatung", type: "consulting")
    visit edit_admin_offer_path(@offer)
    click_menu "Termine"

    within_window(open_new_window) do
      visit edit_admin_offer_path(other)
      click_menu "Termine"
      click_menu "Angebote"

      assert_current_path edit_admin_offer_path(other)
    end

    click_menu "Angebote"

    assert_current_path edit_admin_offer_path(@offer)
  end

  # Saving in a modal morphs the list into its new state, menu bar included.
  test "the menu still leads back after a list refreshed itself" do
    visit edit_admin_offer_path(@offer)
    visit admin_topics_path

    find("a[href='#{new_admin_topic_path}']").click
    fill_in "topic_title", with: "Recherche"
    click_on "Speichern"

    assert_no_selector ".modal, .modal-backdrop", visible: :all
    assert_text "Recherche"

    click_menu "Angebote"

    assert_current_path edit_admin_offer_path(@offer)
  end

  test "a new login forgets the pages of the last" do
    visit edit_admin_offer_path(@offer)
    click_menu "Termine"
    accept_confirm { within("#admin-navbar") { click_on "Abmelden" } }

    assert_current_path root_path

    log_in_admin
    click_menu "Angebote"

    assert_current_path admin_offers_path
  end

  private

  # Waits for the area to show, so that the next click does not land on the
  # page before.
  def click_menu(area)
    within("#admin-navbar") { click_on area }

    assert_selector "#admin-navbar .nav-link.active", text: area
  end

end
