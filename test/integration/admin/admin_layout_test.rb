require "test_helper"

# The admin area has a layout of its own: a compact app bar, a breadcrumb strip
# and the full width of the window, without the decoration of the public site.
# The public site must not notice any of it.
module Admin
  class AdminLayoutTest < ActionDispatch::IntegrationTest

    include AdminLogin
    include MailerRecords

    setup do
      @offer = create_offer
      @event = create_event
    end

    test "admin pages use the full width without the public decoration" do
      log_in_admin
      get admin_events_path

      assert_select "body.admin-ui"
      assert_select "main.admin-page > .container-fluid"
      assert_select "#admin-breadcrumb .container-fluid"
      assert_select "#breadcrumb", count: 0
      assert_select "#footer", count: 0
      assert_select ".container", count: 0
    end

    # Bootstrap's text-bg-light forces black text, which the dark mode cannot
    # turn light, so the facts in the heads use badges of their own.
    test "the heads show their facts in badges that follow the colour mode" do
      log_in_admin

      [admin_offer_event_registrations_path(@offer, @event), admin_offer_events_path(@offer)].each do |path|
        get path

        assert_select ".context-head .context-badge", {minimum: 1}, "for #{path}"
        assert_select ".context-head .text-bg-light", {count: 0}, "for #{path}"
      end
    end

    test "the login page shows the app bar without the menu" do
      get new_admin_session_path

      assert_select "body.admin-ui"
      assert_select "#admin-navbar", text: /Schulung & Beratung/
      assert_select "#admin-navbar .nav-link", count: 0
    end

    test "the public site keeps its layout" do
      get frontend_offers_path

      assert_response :success
      assert_select "body.admin-ui", count: 0
      assert_select "#header"
      assert_select "#breadcrumb .container"
      assert_select "#footer"
      assert_select "#admin-navbar", count: 0
    end

  end
end
