require "application_system_test_case"

# The offer list in the admin and its selection for the bulk actions, which
# the checkbox-select-all controller keeps in step with the rows.
class OfferListTest < ApplicationSystemTestCase

  setup { log_in_admin }

  test "a page visited after the offer list runs without script errors" do
    Offer.create!(title: "Publikationsberatung", type: "consulting")
    visit admin_offers_path
    collect_script_errors

    click_on "Publikationsberatung"

    assert_selector "h5", text: "Angebotsdaten"
    assert_empty script_errors
  end

  # Turbo restores the list from its cache with the rows still checked.
  test "a partial selection still shows on the select-all checkbox after going back" do
    Offer.create!(title: "Literaturrecherche", type: "course")
    Offer.create!(title: "Publikationsberatung", type: "consulting")
    visit admin_offers_path

    first("input[name='bulk_process_ids[]']").click

    assert_select_all_undecided

    click_on "Publikationsberatung"

    assert_selector "h5", text: "Angebotsdaten"

    go_back

    assert_selector "input[name='bulk_process_ids[]']:checked", count: 1
    assert_select_all_undecided
  end

  private

  def assert_select_all_undecided
    assert evaluate_script("document.querySelector('#bulk_process_select_all').indeterminate"),
           "Expected the select-all checkbox to show a partial selection"
  end

end
