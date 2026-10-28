require "test_helper"

# The front end leads to lists of offers filtered by type, topic or target
# group, by the short URLs of these filters.
module Frontend
  class OfferLinksTest < ActionDispatch::IntegrationTest

    setup do
      @topic = Topic.create!(title: "Recherche")
      @group = TargetGroup.create!(title: "Studierende")
    end

    test "the home page leads to the self study courses, the topics and the target groups" do
      get root_path

      assert_select "a[href=?]", "/angebote?scope=self-study-courses"
      assert_select "a[href=?]", "/angebote?topics=#{@topic.id}"
      assert_select "a[href=?]", "/angebote?target-groups=#{@group.id}"
    end

    test "the badges of an offer lead to its type, its topics and its target groups" do
      offer = Offer.create!(title: "Literaturrecherche", type: "course", published: true,
                            topics: [@topic], target_groups: [@group])

      get frontend_offer_path(offer)

      assert_select "a[href=?]", "/angebote?scope=courses"
      assert_select "a[href=?]", "/angebote?topics=#{@topic.id}"
      assert_select "a[href=?]", "/angebote?target-groups=#{@group.id}"
    end

    test "the breadcrumbs of an offer lead to the list of its type" do
      course = Offer.create!(title: "Literaturrecherche", type: "course", published: true)
      consulting = Offer.create!(title: "Publikationsberatung", type: "consulting", published: true)

      get frontend_offer_path(course)

      assert_select ".breadcrumb a[href=?]", "/angebote?scope=courses"

      get frontend_offer_path(consulting)

      assert_select ".breadcrumb a[href=?]", "/angebote?scope=consultings"
    end

  end
end
