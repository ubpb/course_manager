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

    teardown { ApplicationMailer.delivery_method = @delivery_method if @delivery_method }

    def deliver_mails_to(delivery_method)
      @delivery_method = ApplicationMailer.delivery_method
      ApplicationMailer.delivery_method = delivery_method
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

    # The menu leads back to the page last seen in another area (see the
    # admin-nav controller), so it names the area of each page and the page to
    # come back to, with its offer context.
    test "the menu names the area and the page to come back to" do
      {admin_events_path => "events",
       edit_admin_offer_path(@offer) => "offers",
       admin_offer_event_registrations_path(@offer, @event, nav_scope: "offer") => "offers",
       admin_topics_path => "master_data"}.each do |path, section|
        get path

        assert_select "#admin-navbar[data-admin-nav-section-value=?][data-admin-nav-path-value=?]", section, path
      end
    end

    test "a form sent back with errors is no page to come back to" do
      patch admin_offer_path(@offer), params: {offer: {title: ""}}

      assert_response :unprocessable_content
      assert_select "#admin-navbar[data-admin-nav-section-value=offers]"
      assert_select "#admin-navbar[data-admin-nav-path-value]", count: 0
    end

    test "the menu leads to the other areas through the pages last seen there" do
      get edit_admin_offer_path(@offer)

      assert_select "#admin-navbar a[data-admin-nav-target=link][data-admin-nav-section=events][href=?]",
                    admin_events_path, text: "Termine"
      assert_select "#admin-navbar a[data-admin-nav-target=link][data-admin-nav-section=offers][href=?]",
                    admin_offers_path, text: "Angebote"
    end

    # The login page forgets the pages of the last login.
    test "the login page has no area" do
      delete admin_session_path
      get new_admin_session_path

      assert_select "#admin-navbar[data-controller=admin-nav]"
      assert_select "#admin-navbar[data-admin-nav-section-value]", count: 0
    end

    # A test system keeps its mails for reading instead of sending them, and
    # staff check them there. The mail viewer has no admin menu to come back
    # with, so it opens in a tab of its own.
    test "the menu links the mails a test system keeps" do
      deliver_mails_to :letter_opener_web
      get admin_offer_event_registrations_path(@offer, @event, nav_scope: "offer")

      assert_select "#admin-navbar a[href=?][target=_blank]", "/admin/mail", text: "Mails"
    end

    test "the menu has no mail link where the mails go out" do
      deliver_mails_to :sendmail
      get admin_events_path

      assert_select "#admin-navbar a[href^='/admin/mail']", count: 0
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
