require "test_helper"

# The filter round trip on the public offers index: a filter leads to the short
# URL of the list, which renders exactly the filters it names, and a clean list
# URL requested by Turbo leads to the filter the tab remembers.
module Frontend
  class OffersFilteringTest < ActionDispatch::IntegrationTest

    setup do
      @scheduled_course = Offer.create!(title: "Testangebot mit Termin", type: "course", published: true)
      @unscheduled_course = Offer.create!(title: "Testangebot ohne Termin", type: "course", published: true)
      @consulting = Offer.create!(title: "Testberatung", type: "consulting", published: true)

      @scheduled_course.events.create!(date_and_time: 1.week.from_now,
                                       max_no_of_participants: 10,
                                       published: true)
    end

    def filter(params)
      get frontend_offers_path(filter: params)

      assert_response :redirect
      follow_redirect!

      assert_response :success
    end

    # The header with which Turbo sends the filters the tab remembers.
    def remembering(query)
      {Filterable::FILTER_STATE_HEADER => {"frontend/offers" => query}.to_json}
    end

    # Titles are matched against the rendered page, so they must not occur in the
    # page chrome ("Beratung" would match the "Beratungsangebote" heading).
    def listed
      [@scheduled_course, @unscheduled_course, @consulting].select do |offer|
        response.body.include?(ERB::Util.html_escape(offer.title))
      end
    end

    test "the scope filter alone" do
      filter(scope: "courses")

      assert_equal [@scheduled_course, @unscheduled_course], listed
    end

    test "the scope filter combined with with_upcoming_events" do
      filter(scope: "courses", with_upcoming_events: "1")

      assert_equal [@scheduled_course], listed
    end

    test "unchecking with_upcoming_events stops filtering by it" do
      filter(scope: "courses", with_upcoming_events: "1")

      assert_equal [@scheduled_course], listed

      # What an unchecked simple_form checkbox submits.
      filter(scope: "courses", with_upcoming_events: "0")

      assert_equal [@scheduled_course, @unscheduled_course], listed
    end

    test "with_upcoming_events is ignored outside the courses scope" do
      filter(scope: "consultings", with_upcoming_events: "1")

      assert_equal [@consulting], listed
    end

    test "a form's filter leads to the short URL of the list" do
      get frontend_offers_path(filter: {scope: "courses", with_upcoming_events: "1", title: ""})

      assert_redirected_to "/angebote?scope=courses&with-upcoming-events=1"
    end

    test "the short URL renders filtered without a redirect" do
      get "/angebote?scope=courses&with-upcoming-events=1"

      assert_response :success
      assert_equal [@scheduled_course], listed
    end

    test "other forms of a filter lead to its short URL" do
      {"/angebote?with-upcoming-events=1&scope=courses" => "/angebote?scope=courses&with-upcoming-events=1",
       "/angebote?scope=courses&title=" => "/angebote?scope=courses",
       "/angebote?scope=courses&commit=Filtern" => "/angebote?scope=courses",
       "/angebote?scope=schulungen" => "/angebote"}.each do |from, to|
        get from

        assert_redirected_to to, from
      end
    end

    test "a title with special characters keeps a stable short URL" do
      @consulting.update!(title: "Recherche & Zitieren, Tübingen")

      filter(title: "Recherche & Zitieren, Tübingen")

      assert_equal "/angebote?title=Recherche+%26+Zitieren,+T%C3%BCbingen", request.fullpath
      assert_equal [@consulting], listed
    end

    test "a clean URL requested by Turbo leads to the filter the tab remembers" do
      get frontend_offers_path, headers: remembering("scope=courses")

      assert_redirected_to "/angebote?scope=courses"
    end

    test "without a remembered filter the clean URL renders unfiltered" do
      [{}, {Filterable::FILTER_STATE_HEADER => "{}"}].each do |headers|
        get frontend_offers_path, headers: headers

        assert_response :success
        assert_equal [@scheduled_course, @unscheduled_course, @consulting], listed
      end
    end

    test "resetting ignores the filter the header still remembers" do
      get frontend_offers_path(reset_filter: true), headers: remembering("scope=courses")

      assert_redirected_to frontend_offers_path

      follow_redirect!(headers: remembering("scope=courses"))

      assert_response :success
      assert_equal [@scheduled_course, @unscheduled_course, @consulting], listed
    end

    test "a malformed or stale header is ignored" do
      ["no json", "[1]", {"frontend/offers" => 5}.to_json,
       {"frontend/offers" => "scope=schulungen&topics=x"}.to_json, {"frontend/offers" => "title=%E0%A4%A"}.to_json,
       {"frontend/offers" => "scope=courses", "pad" => "x" * 5000}.to_json].each do |value|
        get frontend_offers_path, headers: {Filterable::FILTER_STATE_HEADER => value}

        assert_response :success, value.first(40)
      end
    end

    test "a header with a partly valid filter leads to the valid rest" do
      get frontend_offers_path, headers: remembering("scope=courses&topics=x&with-upcoming-events=ja")

      assert_redirected_to "/angebote?scope=courses"
    end

    test "a short param given as a list or a hash is unset" do
      {"/angebote?scope=courses&topics[]=3" => "/angebote?scope=courses",
       "/angebote?scope=courses&title[a]=b" => "/angebote?scope=courses"}.each do |from, to|
        get from

        assert_redirected_to to, from
      end
    end

    # RACK_QUERY_PARSER_PARAMS_LIMIT can lower the number of params Rack parses
    # below what a header of 4 KB holds.
    test "a remembered filter does not depend on the params limit of the query parser" do
      parser = Rack::Utils.default_query_parser
      Rack::Utils.default_query_parser = Rack::QueryParser.make_default(32, params_limit: 2)

      get frontend_offers_path, headers: remembering("scope=courses&with-upcoming-events=1&title=Test")

      assert_redirected_to "/angebote?scope=courses&with-upcoming-events=1&title=Test"
    ensure
      Rack::Utils.default_query_parser = parser
    end

    test "every filter of the list leads to a URL that renders" do
      topic = Topic.create!(title: "Recherche")
      group = TargetGroup.create!(title: "Studierende")

      filter(scope: "courses", with_upcoming_events: "1", title: "Test", topics: [topic.id],
             target_groups: [group.id])

      assert_equal "/angebote?scope=courses&with-upcoming-events=1&title=Test" \
                   "&target-groups=#{group.id}&topics=#{topic.id}", request.fullpath
    end

    test "removing a filter through its chip drops only that filter" do
      filter(scope: "courses", with_upcoming_events: "1")

      assert_equal [@scheduled_course], listed

      chip = css_select("span.badge").find { |badge| badge.text.include?("Mit anstehenden Terminen") }

      assert chip, "expected a chip for the with_upcoming_events filter"

      get chip.at_css("a")["href"]

      assert_response :success

      assert_equal [@scheduled_course, @unscheduled_course], listed
      assert_empty(css_select("span.badge").select { |badge| badge.text.include?("Mit anstehenden Terminen") })
    end

    test "an unset filter has no chip" do
      filter(scope: "courses", with_upcoming_events: "0")

      assert_empty(css_select("span.badge").select { |badge| badge.text.include?("Mit anstehenden Terminen") })
    end

    test "the self study scope" do
      self_study = Offer.create!(title: "Testkurs zum Selbstlernen", type: "self_study_course", published: true)

      filter(scope: "self_study_courses")

      assert_includes response.body, self_study.title
      assert_empty listed
    end

    test "an unknown scope does not filter" do
      filter(scope: "seminars")

      assert_equal [@scheduled_course, @unscheduled_course, @consulting], listed
    end

    test "the title filter matches a part of the title" do
      filter(title: "ohne Termin")

      assert_equal [@unscheduled_course], listed
    end

    test "topics and target groups each filter by any of the chosen ones" do
      recherche = Topic.create!(title: "Recherche")
      publizieren = Topic.create!(title: "Publizieren")
      studierende = TargetGroup.create!(title: "Studierende")
      @scheduled_course.update!(topics: [recherche, publizieren], target_groups: [studierende])
      @consulting.update!(topics: [publizieren])

      filter(topics: [recherche.id, publizieren.id])

      assert_equal [@scheduled_course, @consulting], listed

      filter(target_groups: [studierende.id])

      assert_equal [@scheduled_course], listed
    end

    test "the chip of one target group removes only that one" do
      studierende = TargetGroup.create!(title: "Studierende")
      lehrende = TargetGroup.create!(title: "Lehrende")
      @unscheduled_course.update!(target_groups: [studierende])
      @consulting.update!(target_groups: [lehrende])

      filter(target_groups: [studierende.id, lehrende.id])

      assert_equal [@unscheduled_course, @consulting], listed

      chip = css_select("span.badge").find { |badge| badge.text.include?("Zielgruppe: Lehrende") }
      get chip.at_css("a")["href"]

      assert_response :success

      assert_equal [@unscheduled_course], listed
    end

    test "a filter param that is not a hash does not raise" do
      get frontend_offers_path(filter: "nonsense")

      assert_response :success
    end

    test "the list tells the tab its key and query, and asks to restore only without the header" do
      get "/angebote?scope=courses"

      assert_select "[data-controller=filter-memory][data-filter-memory-key-value='frontend/offers']" \
                    "[data-filter-memory-query-value='scope=courses']:not([data-filter-memory-restore-value])"

      get frontend_offers_path

      assert_select "[data-controller=filter-memory][data-filter-memory-restore-value]"

      get frontend_offers_path, headers: {Filterable::FILTER_STATE_HEADER => "{}"}

      assert_select "[data-controller=filter-memory]:not([data-filter-memory-restore-value])"
    end

    test "the list after a reset does not ask to restore what the tab remembers" do
      get frontend_offers_path(reset_filter: true)
      follow_redirect!

      assert_select "[data-controller=filter-memory]:not([data-filter-memory-restore-value])"
    end

  end
end
