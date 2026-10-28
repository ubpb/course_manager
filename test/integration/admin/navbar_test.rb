require "test_helper"

# The admin areas sit in a fixed menu bar that marks where staff are, and the
# breadcrumb shows the path inside the admin area only.
module Admin
  class NavbarTest < ActionDispatch::IntegrationTest

    include AdminLogin
    include MailerRecords

    setup do
      @offer = create_offer
      @event = create_event

      log_in_admin
    end

    test "the menu marks the area" do
      {admin_events_path => "Termine",
       admin_offer_event_registrations_path(@offer, @event) => "Termine",
       admin_offer_event_registrations_path(@offer, @event, nav_scope: "offer") => "Angebote",
       admin_offers_path => "Angebote",
       admin_offer_events_path(@offer) => "Angebote",
       edit_admin_offer_path(@offer) => "Angebote",
       admin_topics_path => "Stammdaten"}.each do |path, label|
        get path

        assert_select "#admin-navbar .nav-link.active", {text: label}, "for #{path}"
      end
    end

    test "the menu leaves the offer context" do
      events = admin_events_path
      get admin_offer_event_registrations_path(@offer, @event, nav_scope: "offer")

      assert_select "#admin-navbar a[href=?]", events
      assert_select "#admin-navbar a[href*='nav_scope']", count: 0
    end

    test "the breadcrumb shows the admin path only and does not link the current page" do
      get admin_events_path

      assert_select "#admin-breadcrumb .breadcrumb-item", count: 1
      assert_select "#admin-breadcrumb .breadcrumb-item[aria-current=page]", text: "Termine"
      assert_select "#admin-breadcrumb .breadcrumb-item a", count: 0
    end

    test "on a participant the breadcrumb links the participant list" do
      registration = create_registration
      get edit_admin_offer_event_registration_path(@offer, @event, registration)

      assert_select "#admin-breadcrumb a[href=?]", admin_offer_event_registrations_path(@offer, @event),
                    text: "Teilnehmer"
      assert_select "#admin-breadcrumb .breadcrumb-item[aria-current=page]", text: "Mustermann, Max"
    end

  end
end
