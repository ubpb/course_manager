require "test_helper"

# The statistics of one offer can be exported from its event list, like the
# statistics of all events from the global list.
class Admin::OfferReportsTest < ActionDispatch::IntegrationTest

  include AdminLogin
  include MailerRecords
  include ReportRecords

  setup do
    @offer = create_offer
    create_report(create_event(date_and_time: 1.week.ago))
    @other = create_offer(title: "Recherche in Fachdatenbanken")
    create_report(create_event(@other, date_and_time: 1.week.ago))

    log_in_admin
  end

  test "the export of an offer holds only its statistics" do
    get reports_admin_offer_events_path(@offer, format: :xlsx)

    assert_response :success
    assert_match(/filename="literaturrecherche_report\.xlsx"/, response.headers["Content-Disposition"])

    strings = Zip::File.open_buffer(StringIO.new(response.body)).read("xl/sharedStrings.xml")

    assert_includes strings, "Literaturrecherche"
    assert_not_includes strings, "Recherche in Fachdatenbanken"
  end

  test "the global export still holds the statistics of all offers" do
    get reports_admin_events_path(format: :xlsx)

    assert_response :success
    assert_match(/filename="report\.xlsx"/, response.headers["Content-Disposition"])

    strings = Zip::File.open_buffer(StringIO.new(response.body)).read("xl/sharedStrings.xml")

    assert_includes strings, "Literaturrecherche"
    assert_includes strings, "Recherche in Fachdatenbanken"
  end

  test "the offer's event list links its export" do
    export = reports_admin_offer_events_path(@offer, format: :xlsx)
    get admin_offer_events_path(@offer)

    assert_select "a[href=?]", export
  end

end
