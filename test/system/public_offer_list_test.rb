require "application_system_test_case"

# The public list of offers folds all but the first two dates of a course; the
# toggle under them unfolds the others and says what a click on it does.
class PublicOfferListTest < ApplicationSystemTestCase

  include MailerRecords

  setup do
    offer = create_offer(title: "Literaturrecherche")
    [1, 2, 3, 4].each { create_event(offer, date_and_time: Time.zone.local(2099, 1, it, 10)) }
  end

  test "the toggle unfolds the other dates and folds them again" do
    visit frontend_offers_path
    collect_script_errors

    assert_text "02.01.2099, 10:00 Uhr"
    assert_no_text "03.01.2099, 10:00 Uhr"
    assert_no_text "Weniger Termine"

    click_on "2 weitere Termine"

    assert_text "03.01.2099, 10:00 Uhr"
    assert_text "04.01.2099, 10:00 Uhr"
    assert_no_text "2 weitere Termine"

    # A collapse ignores the toggle while it is still opening.
    wait_for_transitions
    click_on "Weniger Termine"

    assert_no_text "03.01.2099, 10:00 Uhr"
    assert_text "2 weitere Termine"
    assert_empty script_errors
  end

end
