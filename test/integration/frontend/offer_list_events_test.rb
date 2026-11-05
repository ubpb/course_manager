require "test_helper"

# The public list of offers shows the next dates of each course under it, one
# per line: the first two at once and the others behind a toggle, so that a
# course with many dates does not stretch the list.
module Frontend
  class OfferListEventsTest < ActionDispatch::IntegrationTest

    include ActionView::RecordIdentifier
    include MailerRecords

    DATE = /\d\d\.\d\d\.\d{4}, \d\d:\d\d Uhr/

    setup { @offer = create_offer(title: "Literaturrecherche") }

    # Creates published dates on the given days of January 2099, at 10 o'clock.
    def create_dates(offer, *days, **attributes)
      days.each { create_event(offer, date_and_time: Time.zone.local(2099, 1, it, 10), **attributes) }
    end

    def offer_card(offer = @offer)
      css_select("##{dom_id(offer)}").first
    end

    def dates_in(element, selector)
      element.css(selector).map { it.text[DATE] }
    end

    # The dates the card of an offer shows at once.
    def shown_dates(offer = @offer)
      card = offer_card(offer)

      (card.css("li") - card.css(".collapse li")).map { it.text[DATE] }
    end

    # The dates behind the toggle, looked up by the target the toggle names.
    def folded_dates(offer = @offer)
      target = toggle(offer)["aria-controls"]

      assert_equal "##{target}", toggle(offer)["href"]

      dates_in(css_select("##{target}.collapse").first, "li")
    end

    def toggle(offer = @offer)
      offer_card(offer).css("[data-bs-toggle='collapse']").first
    end

    test "a course with up to two dates shows them all, without a toggle" do
      create_dates(@offer, 2, 1)

      get frontend_offers_path

      assert_equal ["01.01.2099, 10:00 Uhr", "02.01.2099, 10:00 Uhr"], shown_dates
      assert_nil toggle
    end

    test "a course with more dates shows the first two and folds the others" do
      create_dates(@offer, 5, 3, 1, 4, 2)

      get frontend_offers_path

      assert_equal ["01.01.2099, 10:00 Uhr", "02.01.2099, 10:00 Uhr"], shown_dates
      assert_equal ["03.01.2099, 10:00 Uhr", "04.01.2099, 10:00 Uhr", "05.01.2099, 10:00 Uhr"], folded_dates
      assert_equal "3 weitere Termine", toggle.at_css(".when-collapsed").text.strip
      assert_equal "Weniger Termine", toggle.at_css(".when-expanded").text.strip
      assert_equal "false", toggle["aria-expanded"]
    end

    test "the toggle names a single folded date in the singular" do
      create_dates(@offer, 1, 2, 3)

      get frontend_offers_path

      assert_equal "1 weiterer Termin", toggle.at_css(".when-collapsed").text.strip
    end

    test "the toggle of each course unfolds the dates of that course" do
      other = create_offer(title: "Zitieren mit Citavi")
      create_dates(@offer, 1, 2, 3)
      create_dates(other, 11, 12, 13)

      get frontend_offers_path

      assert_equal ["03.01.2099, 10:00 Uhr"], folded_dates
      assert_equal ["13.01.2099, 10:00 Uhr"], folded_dates(other)
    end

    test "unpublished and past dates are left out" do
      create_dates(@offer, 1, 2)
      create_dates(@offer, 3, published: false)
      create_event(@offer, date_and_time: Time.zone.local(2000, 1, 1, 10))

      get frontend_offers_path

      assert_equal ["01.01.2099, 10:00 Uhr", "02.01.2099, 10:00 Uhr"], shown_dates
      assert_nil toggle
    end

    test "the dates of all courses are loaded with a single query" do
      create_dates(@offer, 1, 2, 3)
      create_dates(create_offer(title: "Zitieren mit Citavi"), 1, 2, 3)

      assert_queries_match(/FROM `events`/, count: 1) { get frontend_offers_path }
      assert_response :success
    end

  end
end
