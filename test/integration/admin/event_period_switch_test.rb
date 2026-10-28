require "test_helper"

# The period of the event lists is a visible switch instead of a field in the
# filter panel. Switching keeps all other filters, and the panel keeps the
# period, although both lead to a URL that names the whole filter.
module Admin
  class EventPeriodSwitchTest < ActionDispatch::IntegrationTest

    include AdminLogin
    include MailerRecords

    setup do
      @offer = create_offer
      create_event(date_and_time: 1.week.from_now, online: true)
      create_event(date_and_time: 1.week.ago, online: true)
      create_event(date_and_time: 2.weeks.ago, online: false)

      log_in_admin
    end

    def period_link(label)
      css_select(".period-switch a").find { |link| link.text.strip == label }["href"]
    end

    test "the switch starts on all events" do
      get admin_events_path

      assert_select ".period-switch a.active", text: "Alle"
      assert_select "table.event-list tbody tr.event-row", count: 3
    end

    test "the period of the last three months names that it includes the upcoming events" do
      get admin_events_path

      assert_select ".period-switch a[title=?]", "Alle kommenden Termine und die der letzten 3 Monate",
                    text: "Kommende + letzte 3 Monate"
    end

    test "switching the period keeps the other filters" do
      get admin_events_path(filter: {online: "true"})
      follow_redirect!
      get period_link("Vergangene")

      assert_response :success

      assert_select ".period-switch a.active", text: "Vergangene"
      assert_select "table.event-list tbody tr.event-row", count: 1
    end

    test "the switch links to the short URL of each period" do
      get admin_events_path(filter: {published: "true"})
      follow_redirect!

      assert_equal "/admin/events?upcoming-or-past=upcoming&published=1", period_link("Kommende")
      assert_equal "/admin/events?published=1", period_link("Alle")
    end

    test "the filter panel keeps the period" do
      get admin_events_path(filter: {upcoming_or_past: "past"})
      follow_redirect!

      assert_select "#offcanvas-filters input[type=hidden][name='filter[upcoming_or_past]'][value=past]"
      assert_select "#offcanvas-filters select[name='filter[upcoming_or_past]']", count: 0
    end

    test "the period is no chip" do
      get admin_events_path(filter: {upcoming_or_past: "past"})
      follow_redirect!

      assert_select ".badge", text: "Vergangene Termine", count: 0
    end

    test "the switch works in the offer context" do
      get admin_offer_events_path(@offer)
      get period_link("Kommende")

      assert_response :success

      assert_select ".period-switch a.active", text: "Kommende"
      assert_select "table.event-list tbody tr.event-row", count: 1
    end

  end
end
