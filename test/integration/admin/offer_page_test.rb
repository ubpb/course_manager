require "test_helper"

# An offer has a page of its own like an event: a head and the tabs Termine
# (courses only) and Angebotsdaten.
module Admin
  class OfferPageTest < ActionDispatch::IntegrationTest

    include AdminLogin
    include MailerRecords

    setup do
      @offer = create_offer
      create_event(date_and_time: 1.week.from_now)
      create_event(date_and_time: 1.week.ago)
      @consulting = create_offer(title: "Beratung Publizieren", type: "consulting")

      log_in_admin
    end

    test "a course has the tabs Termine and Angebotsdaten" do
      get admin_offer_events_path(@offer)

      assert_select ".offer-tabs .nav-link.active", text: /Termine/
      assert_select ".offer-tabs .nav-link[href=?]", edit_admin_offer_path(@offer), text: "Angebotsdaten"

      get edit_admin_offer_path(@offer)

      assert_select ".offer-tabs .nav-link.active", text: "Angebotsdaten"
    end

    test "other offers only have their data" do
      get edit_admin_offer_path(@consulting)

      assert_select ".offer-tabs .nav-link", count: 1, text: "Angebotsdaten"
      assert_select ".context-head-offer", text: /Beratung/
    end

    test "other offers have no event list to go to" do
      get admin_offer_events_path(@consulting), headers: {"Referer" => admin_offers_url}

      assert_redirected_to admin_offers_url
      assert_equal "Nur Kurse können Termine haben.", flash[:alert]
    end

    test "the head counts the events of a course and says nothing about statistics" do
      get admin_offer_events_path(@offer)

      assert_select ".context-head-offer .badge", text: "1 kommende"
      assert_select ".context-head-offer .badge", text: "1 vergangene"
      assert_select ".context-head-offer", text: /Statistik/, count: 0
    end

    test "the head marks an archived offer" do
      @offer.update!(archived: true)
      get edit_admin_offer_path(@offer)

      assert_response :success
      assert_select ".context-head-offer .badge", text: "archiviert"
    end

    test "the offer list opens the offer page" do
      get admin_offers_path

      assert_select "a[href=?]", admin_offer_events_path(@offer), text: "Literaturrecherche"
      assert_select "a[href=?]", edit_admin_offer_path(@consulting), text: "Beratung Publizieren"
    end

    test "the offer list shows the status as a badge" do
      get admin_offers_path

      assert_select "#offer_#{@offer.id} .status-badge", text: "veröffentlicht"
    end

    test "a failed save keeps the head on the stored offer" do
      patch admin_offer_path(@offer), params: {offer: {title: "", published: "0", type: "consulting"}}

      assert_response :unprocessable_content
      assert_select ".context-head-offer h2", text: "Literaturrecherche"
      assert_select ".context-head-offer .status-badge", text: "veröffentlicht"
      assert_select ".offer-tabs .nav-link", text: /Termine/
    end

  end
end
