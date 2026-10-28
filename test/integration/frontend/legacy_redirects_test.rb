require "test_helper"

# The old site had separate pages for courses, consultings and events. Their
# URLs live on in bookmarks and search engines and lead permanently to the
# offer they showed, or to the matching list where there is none.
module Frontend
  class LegacyRedirectsTest < ActionDispatch::IntegrationTest

    include MailerRecords

    setup do
      @course = create_offer(title: "Literaturrecherche", old_id: 7)
      @consulting = create_offer(title: "Publikationsberatung", type: "consulting", old_id: 7)
      @event = create_event(@course, date_and_time: 1.week.from_now)
    end

    def assert_moved_to(path)
      assert_response :moved_permanently
      assert_redirected_to path
    end

    test "an old course page leads to the course" do
      get "/angebote/kurse/7"

      assert_moved_to frontend_offer_path(@course)
    end

    test "an unknown or missing course leads to the course list" do
      ["/angebote/kurse/99", "/angebote/kurse"].each do |path|
        get path

        assert_moved_to "/angebote?scope=courses"
      end
    end

    test "an old consulting page leads to the consulting" do
      get "/angebote/beratungen/7"

      assert_moved_to frontend_offer_path(@consulting)
    end

    test "an unknown or missing consulting leads to the consulting list" do
      ["/angebote/beratungen/99", "/angebote/beratungen"].each do |path|
        get path

        assert_moved_to "/angebote?scope=consultings"
      end
    end

    test "an old event page leads to the offer it belongs to" do
      get "/angebote/termine/#{@event.id}"

      assert_moved_to frontend_offer_path(@course)
    end

    test "an unknown or missing event leads to the courses with upcoming events" do
      ["/angebote/termine/0", "/angebote/termine"].each do |path|
        get path

        assert_moved_to "/angebote?scope=courses&with-upcoming-events=1"
      end
    end

    # The offer page answers 404 for these; a permanent redirect there would
    # send bookmarks and search engines to a dead end for good.
    test "an offer that is archived or unpublished leads to the list instead" do
      @course.update!(archived: true)
      @consulting.update!(published: false)

      get "/angebote/kurse/7"

      assert_moved_to "/angebote?scope=courses"

      get "/angebote/beratungen/7"

      assert_moved_to "/angebote?scope=consultings"

      get "/angebote/termine/#{@event.id}"

      assert_moved_to "/angebote?scope=courses&with-upcoming-events=1"
    end

  end
end
