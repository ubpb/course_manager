require "test_helper"

# Every set filter shows as a chip that removes just that filter -- or, for
# topics and target groups, just that one value.
class FilterChipHelperTest < ActionView::TestCase

  FILTERS = {scope: :string, title: :string, online: :boolean, published: :boolean,
             with_upcoming_events: :flag, with_report: :boolean, include_archived: :flag,
             from_date: :date, to_date: :date, topics: :integer, target_groups: :integer}.freeze

  # The remove paths are checked as the params they are built from.
  def url_for(options)
    options
  end

  def build_filter(params = {})
    context = Filterable::FilterContext.new
    FILTERS.each { |name, type| context.filter_by(name, type) }
    Filterable::Filter.new(filter_context: context, filter_params: params)
  end

  def chips(params, *keys)
    filter_chips_for(build_filter(params), *keys)
  end

  def labels(params, *)
    chips(params, *).pluck(:label)
  end

  test "no filter and an inactive filter have no chips" do
    assert_empty filter_chips_for(nil, :scope)
    assert_empty chips({}, FILTERS.keys)
  end

  test "the scope is named, an unknown one as it is" do
    assert_equal ["Schulungen"], labels({scope: "courses"}, :scope)
    assert_equal ["Beratungen"], labels({scope: "consultings"}, :scope)
    assert_equal ["Selbstlernkurse"], labels({scope: "self_study_courses"}, :scope)
    assert_equal ["sonstiges"], labels({scope: "sonstiges"}, :scope)
  end

  test "an unset filter has no chip while others are set" do
    assert_empty labels({title: "Recherche"}, :scope, :online, :published, :with_upcoming_events, :with_report,
                        :include_archived, :from_date, :to_date)
  end

  test "the chips of the plain filters" do
    params = {title: "Recherche", published: "true", with_upcoming_events: "1", include_archived: "1",
              from_date: "2026-11-01", to_date: "2026-11-30"}

    assert_equal ["Titel: Recherche", "Veröffentlicht: Ja", "Mit anstehenden Terminen", "Archivierte anzeigen",
                  "Ab 01.11.2026", "Bis 30.11.2026"],
                 labels(params, :title, :published, :with_upcoming_events, :include_archived, :from_date, :to_date)
  end

  test "yes-or-no filters name both answers" do
    assert_equal ["Online", "Veröffentlicht: Ja", "Mit Bericht"],
                 labels({online: "true", published: "true", with_report: "true"}, :online, :published, :with_report)
    assert_equal ["Präsenz", "Veröffentlicht: Nein", "Ohne Bericht"],
                 labels({online: "false", published: "false", with_report: "false"}, :online, :published, :with_report)
  end

  test "an unknown key has no chip" do
    assert_empty labels({title: "Recherche"}, :unknown)
  end

  test "each topic and target group has a chip of its own, in their order" do
    second = Topic.create!(title: "Publizieren")
    first = Topic.create!(title: "Recherche").tap(&:move_to_top)
    group = TargetGroup.create!(title: "Studierende")

    params = {topics: [second.id, first.id], target_groups: [group.id]}

    assert_equal ["Thema: Recherche", "Thema: Publizieren", "Zielgruppe: Studierende"],
                 labels(params, :topics, :target_groups)
  end

  test "a chip removes its filter and keeps the others" do
    chip = chips({title: "Recherche", scope: "courses"}, :title).sole

    assert_equal({filter: {"scope" => "courses"}}, chip[:remove_path])
  end

  test "the chip of one topic removes only that topic" do
    recherche = Topic.create!(title: "Recherche")
    publizieren = Topic.create!(title: "Publizieren")

    chip = chips({topics: [recherche.id, publizieren.id]}, :topics).first

    assert_equal({filter: {"topics" => [publizieren.id]}}, chip[:remove_path])
  end

  test "removing the last filter resets the list" do
    topic = Topic.create!(title: "Recherche")

    assert_equal({reset_filter: true}, chips({topics: [topic.id]}, :topics).sole[:remove_path])
    assert_equal({reset_filter: true}, chips({title: "Recherche"}, :title).sole[:remove_path])
  end

end
