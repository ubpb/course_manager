require "test_helper"

# Each filter of the event lists narrows the list on its own, and the export of
# the statistics covers the period the date filters span.
module Admin
  class EventFiltersTest < ActionDispatch::IntegrationTest

    include AdminLogin
    include MailerRecords
    include ReportRecords

    setup do
      travel_to Time.zone.parse("2026-10-28 12:00")
      @offer = create_offer
      @next_week = create_event(date_and_time: Time.zone.parse("2026-11-04 10:00"), online: true)
      @last_month = create_event(date_and_time: Time.zone.parse("2026-09-30 10:00"), published: false)
      @last_year = create_event(date_and_time: Time.zone.parse("2025-10-01 10:00"))
      create_report(@last_month)
      @other = create_offer(title: "Recherche in Fachdatenbanken")
      @other_event = create_event(@other, date_and_time: Time.zone.parse("2026-11-11 10:00"))
      log_in_admin
    end

    def filter(params)
      get admin_events_path(filter: params)

      assert_response :redirect
      follow_redirect!

      assert_response :success
    end

    def listed
      [@next_week, @last_month, @last_year, @other_event].select do |event|
        css_select("tr[data-row-link-url-value='#{admin_offer_event_registrations_path(event.offer, event)}']").any?
      end
    end

    test "the period narrows the list" do
      filter(upcoming_or_past: "upcoming")

      assert_equal [@next_week, @other_event], listed

      filter(upcoming_or_past: "upcoming_and_last_3_months")

      assert_equal [@next_week, @last_month, @other_event], listed

      filter(upcoming_or_past: "past")

      assert_equal [@last_month, @last_year], listed
    end

    test "an unknown period does not filter" do
      filter(upcoming_or_past: "someday")

      assert_equal [@next_week, @last_month, @last_year, @other_event], listed
    end

    test "publication, kind and statistics narrow the list" do
      filter(published: "false")

      assert_equal [@last_month], listed

      filter(online: "true")

      assert_equal [@next_week], listed

      filter(with_report: "true")

      assert_equal [@last_month], listed

      filter(with_report: "false")

      assert_equal [@next_week, @last_year, @other_event], listed
    end

    # Events have no delivery format (any more); the parameter must not reach
    # the database.
    test "a delivery format is no filter" do
      filter(delivery_format: "1")

      assert_response :success
      assert_equal [@next_week, @last_month, @last_year, @other_event], listed
    end

    test "the title of the offer narrows the list" do
      filter(title: "Fachdatenbanken")

      assert_equal [@other_event], listed
    end

    test "the dates narrow the list to whole days" do
      filter(from_date: "2026-09-30", to_date: "2026-11-04")

      assert_equal [@next_week, @last_month], listed
    end

    test "every filter of the list leads to a URL that renders" do
      filter(upcoming_or_past: "upcoming_and_last_3_months", published: "true", online: "false", with_report: "true",
             title: "Recherche", from_date: "2026-10-01", to_date: "2026-12-31")

      assert_equal "/admin/events?upcoming-or-past=upcoming-and-last-3-months&published=1&online=0&with-report=1" \
                   "&title=Recherche&from-date=2026-10-01&to-date=2026-12-31", request.fullpath
    end

    test "the export of the statistics is named after the period of the date filters" do
      get reports_admin_events_path(format: :xlsx, filter: {from_date: "2026-09-01", to_date: "2026-09-30"})
      follow_redirect!

      assert_response :success
      assert_equal 'attachment; filename="2026-09-01_2026-09-30_report.xlsx"', response.headers["Content-Disposition"]

      # The export of the offer's list covers what its own URL names, here nothing.
      get reports_admin_offer_events_path(@offer, format: :xlsx)

      assert_equal 'attachment; filename="literaturrecherche_report.xlsx"', response.headers["Content-Disposition"]
    end

  end
end
