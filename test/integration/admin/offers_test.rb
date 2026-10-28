require "test_helper"

# The offer list of the admin with its filters and the archive bulk action, and
# creating, saving and deleting an offer.
module Admin
  class OffersTest < ActionDispatch::IntegrationTest

    include AdminLogin

    setup do
      @course = Offer.create!(title: "Literaturrecherche", type: "course", published: true)
      @consulting = Offer.create!(title: "Publikationsberatung", type: "consulting", published: false)
      @self_study = Offer.create!(title: "Zitieren lernen", type: "self_study_course", published: true)
      @archived = Offer.create!(title: "Alte Datenbankschulung", type: "course", archived: true)
      log_in_admin
    end

    def filter(params)
      get admin_offers_path(filter: params)

      assert_redirected_to admin_offers_path
      follow_redirect!
    end

    def listed
      [@course, @consulting, @self_study, @archived].select do |offer|
        css_select("a[href='#{offer_page_path(offer)}']").any?
      end
    end

    # Courses open on their event list, other offers on their data.
    def offer_page_path(offer)
      offer.course? ? admin_offer_events_path(offer) : edit_admin_offer_path(offer)
    end

    test "the list leaves out archived offers" do
      get admin_offers_path

      assert_response :success
      assert_equal [@course, @consulting, @self_study], listed
    end

    test "archived offers can be shown too" do
      filter(include_archived: "1")

      assert_equal [@course, @consulting, @self_study, @archived], listed
      assert_includes response.body, "Archivierte anzeigen"
    end

    {"courses" => :@course, "consultings" => :@consulting, "self_study_courses" => :@self_study}.each do |scope, offer|
      test "the list filters by the type #{scope}" do
        filter(scope: scope)

        assert_equal [instance_variable_get(offer)], listed
      end
    end

    test "an unknown type does not filter" do
      filter(scope: "unknown")

      assert_equal [@course, @consulting, @self_study], listed
    end

    test "the list filters by publication" do
      filter(published: "false")

      assert_equal [@consulting], listed
    end

    test "the list filters by a part of the title" do
      filter(title: "recherche")

      assert_equal [@course], listed
    end

    test "the title filter takes a percent sign literally" do
      filter(title: "%")

      assert_empty listed
    end

    test "the list offers to archive its offers" do
      get admin_offers_path

      assert_select "select#bulk_process_action option[value=archive]"
    end

    test "an empty list offers no bulk action" do
      filter(title: "nichts dergleichen")

      assert_select "select#bulk_process_action", count: 0
    end

    test "archiving takes the selected offers out of the list" do
      patch bulk_process_admin_offers_path, params: {bulk_process_action: "archive", bulk_process_ids: [@course.id]}

      assert_redirected_to admin_offers_path
      assert_equal "Angebot(e) wurde archiviert", flash[:success]
      assert_predicate @course.reload, :archived?
      assert_not_predicate @consulting.reload, :archived?
    end

    test "an unknown bulk action changes nothing" do
      patch bulk_process_admin_offers_path, params: {bulk_process_action: "unknown", bulk_process_ids: [@course.id]}

      assert_redirected_to admin_offers_path
      assert_nil flash[:success]
      assert_not_predicate @course.reload, :archived?
    end

    test "a new offer starts as a course" do
      get new_admin_offer_path

      assert_response :success
      assert_select "select[name='offer[type]'] option[value=course][selected]"
    end

    test "a new offer is saved with its topics and target groups" do
      topic = Topic.create!(title: "Recherche")
      target_group = TargetGroup.create!(title: "Studierende")

      assert_difference -> { Offer.count }, 1 do
        post admin_offers_path, params: {offer: {type: "consulting", title: "Datenmanagement",
                                                 topic_ids: [topic.id], target_group_ids: [target_group.id]}}
      end

      offer = Offer.last

      assert_redirected_to edit_admin_offer_path(offer)
      assert_equal [topic], offer.topics
      assert_equal [target_group], offer.target_groups
    end

    test "a new offer without a title shows the form again" do
      assert_no_difference -> { Offer.count } do
        post admin_offers_path, params: {offer: {type: "course", title: ""}}
      end

      assert_response :unprocessable_content
    end

    test "saving an offer leads back to its data" do
      patch admin_offer_path(@course), params: {offer: {title: "Literaturrecherche kompakt"}}

      assert_equal "Literaturrecherche kompakt", @course.reload.title
      assert_redirected_to edit_admin_offer_path(@course)
    end

    test "an offer with a foreign contact address is not saved" do
      patch admin_offer_path(@course), params: {offer: {contact_email: "someone@example.com"}}

      assert_response :unprocessable_content
      assert_nil @course.reload[:contact_email]
    end

    test "deleting an offer leads back to the list" do
      delete admin_offer_path(@course)

      assert_redirected_to admin_offers_path
      assert_not Offer.exists?(@course.id)
    end

  end
end
