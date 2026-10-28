require "test_helper"

# The global event list and the event list of an offer are one list: same
# columns, filters and actions, the offer's list only without the offer column.
module Admin
  class EventListTest < ActionDispatch::IntegrationTest

    include ActionView::RecordIdentifier
    include AdminLogin
    include MailerRecords

    setup do
      @offer = create_offer
      @upcoming = create_event(date_and_time: 1.week.from_now, online: true)
      @past = create_event(date_and_time: 1.week.ago)
      @other = create_offer(title: "Recherche in Fachdatenbanken")
      create_event(@other, date_and_time: 2.weeks.from_now)

      log_in_admin
    end

    test "the offer's list shows only its events, without an offer column" do
      get admin_offer_events_path(@offer)

      assert_select "table.event-list tbody tr.event-row", count: 2
      assert_select "table.event-list", text: /Recherche in Fachdatenbanken/, count: 0
      assert_select "table.event-list th", text: "Angebot", count: 0
    end

    test "the global list shows the offer" do
      get admin_events_path

      assert_select "table.event-list th", text: "Angebot"
      assert_select "a[href=?]", admin_offer_events_path(@offer), text: "Literaturrecherche"
    end

    test "rows open the event in the context of their list" do
      in_offer = admin_offer_event_registrations_path(@offer, @upcoming, nav_scope: "offer")
      global = admin_offer_event_registrations_path(@offer, @upcoming)

      get admin_offer_events_path(@offer)

      assert_select "tr[data-row-link-url-value=?]", in_offer

      get admin_events_path

      assert_select "tr[data-row-link-url-value=?]", global
    end

    test "filters work in the offer context and are kept apart from the global list" do
      get admin_offer_events_path(@offer, filter: {online: "true"})
      follow_redirect!

      assert_select "table.event-list tbody tr.event-row", count: 1

      get admin_events_path

      assert_select "table.event-list tbody tr.event-row", count: 3
    end

    test "the offer context has no title filter" do
      get admin_offer_events_path(@offer)

      assert_select "#offcanvas-filters input[name='filter[title]']", count: 0
    end

    test "missing statistics are marked for past events only" do
      get admin_offer_events_path(@offer)

      assert_select "##{dom_id(@past)} .status-badge.status-missing", text: "fehlt"
      assert_select "##{dom_id(@upcoming)} .status-missing", count: 0
    end

    test "both lists offer to duplicate" do
      duplicate = duplicate_admin_offer_event_path(@offer, @upcoming)

      [admin_events_path, admin_offer_events_path(@offer)].each do |path|
        get path

        assert_select "a[href^=?]", duplicate
      end
    end

    test "bulk actions still work in the offer context" do
      @upcoming.update!(published: false)
      patch bulk_process_admin_offer_events_path(@offer),
            params: {bulk_process_action: "publish", bulk_process_ids: [@upcoming.id]}

      assert_redirected_to admin_offer_events_path(@offer)
      assert_predicate @upcoming.reload, :published?
    end

    test "moving events opens the dialog in the offer context" do
      patch bulk_process_admin_offer_events_path(@offer),
            params: {bulk_process_action: "move_to_offer", bulk_process_ids: [@upcoming.id]},
            headers: {"Accept" => "text/vnd.turbo-stream.html, text/html"}

      assert_includes response.body, '<turbo-stream action="replace" target="bulk-action-form">'
    end

    test "moving without a selected event asks for one" do
      patch bulk_process_admin_events_path, params: {bulk_process_action: "move_to_offer"}

      assert_redirected_to admin_events_path
      assert_equal "Bitte mindestens einen Termin auswählen", flash[:alert]
    end

    test "an unknown bulk action changes nothing" do
      patch bulk_process_admin_events_path, params: {bulk_process_action: "unknown", bulk_process_ids: [@upcoming.id]}

      assert_redirected_to admin_events_path
      assert_predicate @upcoming.reload, :published?
    end

    test "bulk actions work in the global list" do
      @upcoming.update!(published: false)
      patch bulk_process_admin_events_path,
            params: {bulk_process_action: "publish", bulk_process_ids: [@upcoming.id]}

      assert_redirected_to admin_events_path
      assert_predicate @upcoming.reload, :published?

      patch bulk_process_admin_events_path,
            params: {bulk_process_action: "unpublish", bulk_process_ids: [@upcoming.id]}

      assert_not_predicate @upcoming.reload, :published?
    end

    test "the move dialog offers every course, in the offer context all but its own" do
      turbo = {"Accept" => "text/vnd.turbo-stream.html, text/html"}
      global_move = bulk_move_admin_events_path
      offer_move = bulk_move_admin_offer_events_path(@offer)

      patch bulk_process_admin_events_path,
            params: {bulk_process_action: "move_to_offer", bulk_process_ids: [@upcoming.id]}, headers: turbo

      assert_includes response.body, %(action="#{global_move}")
      assert_includes response.body, ">Literaturrecherche</option>"
      assert_includes response.body, ">Recherche in Fachdatenbanken</option>"

      patch bulk_process_admin_offer_events_path(@offer),
            params: {bulk_process_action: "move_to_offer", bulk_process_ids: [@upcoming.id]}, headers: turbo

      assert_includes response.body, %(action="#{offer_move}")
      assert_not_includes response.body, ">Literaturrecherche</option>"
      assert_includes response.body, ">Recherche in Fachdatenbanken</option>"
    end

    test "moving events puts them into the chosen course and returns to the list" do
      global_list = admin_events_path
      other_list = admin_offer_events_path(@other)

      patch bulk_move_admin_events_path, params: {event_ids: [@upcoming.id], target_offer_id: @other.id}

      assert_redirected_to global_list
      assert_equal @other, @upcoming.reload.offer

      patch bulk_move_admin_offer_events_path(@other), params: {event_ids: [@upcoming.id], target_offer_id: @offer.id}

      assert_redirected_to other_list
      assert_equal @offer, @upcoming.reload.offer
    end

    test "an offer moves neither into itself nor the events of another offer" do
      patch bulk_move_admin_offer_events_path(@offer), params: {event_ids: [@upcoming.id], target_offer_id: @offer.id}

      assert_equal "Bitte Termine und Ziel-Angebot auswählen", flash[:alert]

      foreign = @other.events.first
      patch bulk_move_admin_offer_events_path(@offer),
            params: {event_ids: [foreign.id], target_offer_id: create_offer(title: "Zotero").id}

      assert_equal "Bitte Termine und Ziel-Angebot auswählen", flash[:alert]
      assert_equal @other, foreign.reload.offer
    end

    # The checkbox and the actions menu sit in cells larger than themselves; a
    # click next to them must not open the event (see row_link_controller.js).
    test "the checkbox and actions cells do not open the event" do
      get admin_events_path

      assert_select "##{dom_id(@upcoming)} td[data-row-link-ignore]", count: 2
      assert_select "##{dom_id(@upcoming)} td.actions[data-row-link-ignore]"
    end

    test "both lists start a new event and export statistics the same way" do
      global_new = new_admin_event_path
      global_export = reports_admin_events_path(format: :xlsx)
      offer_new = new_admin_offer_event_path(@offer, nav_scope: "offer")
      offer_export = reports_admin_offer_events_path(@offer, format: :xlsx)

      get admin_events_path

      assert_select ".card-header a.btn[href=?]", global_new, text: "Neuer Termin"
      assert_select ".card-header a.btn[href=?]", global_export, text: "Statistik (Excel)"

      get admin_offer_events_path(@offer)

      assert_select ".card-header a.btn[href=?]", offer_new, text: "Neuer Termin"
      assert_select ".card-header a.btn[href=?]", offer_export, text: "Statistik (Excel)"
    end

    # The rows are grouped by month, and a line marks today between the upcoming
    # and the past events.
    test "the list is grouped by month with a line for today" do
      travel_to Time.zone.parse("2026-10-27 12:00") do
        @upcoming.update!(date_and_time: Time.zone.parse("2026-11-03 10:00"))
        @past.update!(date_and_time: Time.zone.parse("2026-10-20 10:00"))

        get admin_offer_events_path(@offer)
      end

      rows = css_select("table.event-list tbody tr").map { |tr| tr["class"].to_s.split.first }

      assert_equal ["event-list-month", "event-row", "event-list-today", "event-list-month", "event-row"], rows
      assert_select "tr.event-list-month", text: "November 2026"
      assert_select "tr.event-list-month", text: "Oktober 2026"
      assert_select "tr.event-list-today", text: /Heute/
    end

    test "a list of upcoming events only has no line for today" do
      get admin_offer_events_path(@offer, filter: {upcoming_or_past: "upcoming"})
      follow_redirect!

      assert_select "tr.event-list-today", count: 0
    end

  end
end
