require "application_system_test_case"

# Each tab remembers the filter of each list: staff who come back to a list --
# through the menu bar, after deleting an entry, or by loading its plain URL --
# find it filtered as they left it in this tab, whatever other tabs do. Back and
# forward show a list as it was.
class ListFiltersTest < ApplicationSystemTestCase

  include MailerRecords

  setup do
    @course = create_offer(title: "Literaturrecherche")
    @consulting = create_offer(title: "Publikationsberatung", type: "consulting")

    log_in_admin
  end

  test "the link of the current area comes back to the remembered filter" do
    visit "/admin/offers?scope=consultings"
    visit edit_admin_offer_path(@consulting)
    collect_script_errors

    click_menu "Angebote"

    assert_current_path "/admin/offers?scope=consultings"
    assert_text "Publikationsberatung"
    assert_no_text "Literaturrecherche"
    assert_empty script_errors
  end

  # Turbo would show its copy of the plain list ahead of the page, which shows
  # the list unfiltered.
  test "coming back to the list shows no unfiltered copy of it ahead" do
    visit admin_offers_path
    execute_script(<<~JS)
      window.previews = [];
      document.addEventListener("turbo:render", () => {
        if (document.documentElement.hasAttribute("data-turbo-preview")) {
          window.previews.push(location.pathname + location.search + " " + document.body.innerText.includes("Literaturrecherche"));
        }
      });
    JS
    execute_script("Turbo.visit('/admin/offers?scope=consultings')")

    assert_current_path "/admin/offers?scope=consultings"

    execute_script("Turbo.visit(#{edit_admin_offer_path(@consulting).to_json})")

    assert_current_path edit_admin_offer_path(@consulting)

    click_menu "Angebote"

    assert_current_path "/admin/offers?scope=consultings"
    unfiltered = evaluate_script("window.previews").select { it.end_with?("true") }

    assert_empty unfiltered
  end

  test "each tab keeps its own filter" do
    visit "/admin/offers?scope=consultings"

    within_window(open_new_window) do
      visit "/admin/offers?scope=courses"
      visit edit_admin_offer_path(@consulting)
      click_menu "Angebote"

      assert_current_path "/admin/offers?scope=courses"
    end

    visit edit_admin_offer_path(@consulting)
    click_menu "Angebote"

    assert_current_path "/admin/offers?scope=consultings"
  end

  test "a plain list URL loaded in full comes back filtered" do
    visit "/admin/offers?scope=consultings"
    visit admin_offers_path

    assert_current_path "/admin/offers?scope=consultings"
    assert_no_text "Literaturrecherche"
  end

  # Should the header get lost on its way (a proxy), the list must not reload
  # itself again and again.
  test "a list reloads itself once when its request loses the remembered filter" do
    visit "/admin/offers?scope=consultings"
    # Runs on every page the browser loads from now on, also in later tests,
    # until removed.
    script = page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: <<~JS)
      window.visits = 0;
      document.addEventListener("turbo:visit", () => window.visits++);
      window.addEventListener("turbo:before-fetch-request", (event) => {
        delete event.detail.fetchOptions.headers["X-Filter-State"];
      });
    JS
    visit admin_offers_path
    evaluate_async_script("setTimeout(arguments[0], 1000)")

    assert_equal 1, evaluate_script("window.visits")
    assert_current_path admin_offers_path
  ensure
    if script
      page.driver.browser.execute_cdp("Page.removeScriptToEvaluateOnNewDocument",
                                      identifier: script["identifier"])
    end
  end

  test "resetting forgets the filter" do
    visit "/admin/offers?scope=consultings"
    click_on "Alle zurücksetzen"

    assert_current_path admin_offers_path

    visit edit_admin_offer_path(@consulting)
    click_menu "Angebote"

    assert_current_path admin_offers_path
    assert_text "Literaturrecherche"
  end

  test "deleting an offer returns to the filtered list with its notice" do
    other = create_offer(title: "Schreibberatung", type: "consulting")
    visit "/admin/offers?scope=consultings"
    visit edit_admin_offer_path(other)

    accept_confirm { click_on "Löschen" }

    assert_selector "#admin-toasts .toast", text: "Erfolgreich gelöscht."
    assert_current_path "/admin/offers?scope=consultings"
    assert_text "Publikationsberatung"
    assert_no_text "Literaturrecherche"
  end

  test "a new login forgets the admin filters" do
    visit "/admin/offers?scope=consultings"

    assert_includes remembered_lists, "admin/offers"

    accept_confirm { within("#admin-navbar") { click_on "Abmelden" } }

    assert_current_path root_path

    log_in_admin

    assert_not_includes remembered_lists, "admin/offers"

    visit admin_offers_path
    # Time for a reload to a remembered filter, had there been one.
    evaluate_async_script("setTimeout(arguments[0], 1000)")

    assert_current_path admin_offers_path
    assert_text "Literaturrecherche"
  end

  test "back shows the list as it was, forward the filtered one" do
    visit admin_offers_path
    execute_script("Turbo.visit('/admin/offers?scope=consultings')")

    assert_current_path "/admin/offers?scope=consultings"

    go_back

    assert_current_path admin_offers_path
    assert_text "Literaturrecherche"

    go_forward

    assert_current_path "/admin/offers?scope=consultings"
    assert_no_text "Literaturrecherche"
  end

  test "back without the cached page also shows the list as it was" do
    visit admin_offers_path
    execute_script("Turbo.visit('/admin/offers?scope=consultings')")

    assert_current_path "/admin/offers?scope=consultings"

    execute_script("Turbo.cache.clear()")
    go_back

    assert_current_path admin_offers_path
    assert_text "Literaturrecherche"
  end

  private

  # The keys of the lists whose filter the tab remembers (filter_state.js).
  def remembered_lists
    JSON.parse(evaluate_script("sessionStorage.getItem('filters')") || "{}").keys
  end

  # Waits for the area to show, so that the next click does not land on the
  # page before.
  def click_menu(area)
    within("#admin-navbar") { click_on area }

    assert_selector "#admin-navbar .nav-link.active", text: area
  end

end
