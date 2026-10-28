require "test_helper"

# The structured data (JSON-LD) search engines read from the frontend pages.
class MetaHelperTest < ActionView::TestCase

  include ApplicationHelper
  include ConfigOverride
  include MailerRecords

  def breadcrumb
    @breadcrumb ||= []
  end

  test "the organization carries its other name and profiles only when configured" do
    with_config(organization: {alternate_name: "UB Paderborn", same_as: ["https://www.wikidata.org/wiki/Q1"]}) do
      data = organization_json_ld

      assert_equal "Organization", data["@type"]
      assert_equal "UB Paderborn", data["alternateName"]
      assert_equal ["https://www.wikidata.org/wiki/Q1"], data["sameAs"]
    end

    with_config(organization: {alternate_name: nil, same_as: []}) do
      data = organization_json_ld

      assert_not data.key?("alternateName")
      assert_not data.key?("sameAs")
    end
  end

  test "the website is published by the organization" do
    assert_equal({"@id" => organization_id}, website_json_ld["publisher"])
  end

  test "a course with nothing more is a bare Course" do
    data = offer_json_ld(create_offer)

    assert_equal "Course", data["@type"]
    assert_equal organization_id, data.dig("provider", "@id")
    assert_not data.key?("about")
    assert_not data.key?("audience")
    assert_not data.key?("hasCourseInstance")
  end

  test "a consulting is a Service about its topics for its target groups" do
    offer = create_offer(type: "consulting", topics: [Topic.create!(title: "Recherche")],
                         target_groups: [TargetGroup.create!(title: "Studierende")])

    data = offer_json_ld(offer)

    assert_equal "Service", data["@type"]
    assert_equal ["Recherche"], data["about"]
    assert_equal [{"@type" => "Audience", "audienceType" => "Studierende"}], data["audience"]
  end

  test "the upcoming events become course instances" do
    @offer = create_offer
    onsite = create_event(date_and_time: Time.zone.parse("2026-11-05 14:00"), duration: 90, location: "Raum 1.2")
    online = create_event(date_and_time: Time.zone.parse("2026-11-06 10:00"), duration: nil, location: nil,
                          online: true)

    instances = offer_json_ld(@offer, [onsite, online])["hasCourseInstance"]

    assert_equal({"@type" => "CourseInstance", "courseMode" => "onsite",
                  "startDate" => "2026-11-05T14:00:00+01:00", "endDate" => "2026-11-05T15:30:00+01:00",
                  "location" => {"@type" => "Place", "name" => "Raum 1.2"}}, instances.first)
    assert_equal({"@type" => "CourseInstance", "courseMode" => "online",
                  "startDate" => "2026-11-06T10:00:00+01:00"}, instances.second)
  end

  test "a breadcrumb trail needs two linked crumbs" do
    breadcrumb << {label: "Angebote", path: "/angebote"}

    assert_nil breadcrumb_json_ld

    breadcrumb << {label: "Literaturrecherche", path: "/angebote/1"}

    assert_equal ["Angebote", "Literaturrecherche"], breadcrumb_json_ld["itemListElement"].pluck("name")
  end

  test "the description comes from the first text with content, else from the site" do
    assert_equal "Erster Absatz", meta_description_for("", "**Erster** Absatz")
    assert_equal t("frontend.meta.default_description"), meta_description_for(nil, "")
    assert_operator meta_description_for("Wort " * 100).length, :<=, 160
  end

end
