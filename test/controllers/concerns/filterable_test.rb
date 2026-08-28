require "test_helper"

# Unit tests for the value semantics of Filterable: casting, unset values,
# defaults, and which filters end up being applied / shown as active.
class FilterableTest < ActiveSupport::TestCase

  # Builds a filter for an ad-hoc context. Blocks append the filter name to a
  # plain array, so `#filter` can be tested without touching the database.
  def build_filter(params = {}, &definitions)
    context = Filterable::FilterContext.new
    context.instance_eval(&definitions)
    Filterable::Filter.new(filter_context: context, filter_params: params)
  end

  # --- casting ---------------------------------------------------------------

  test "casts values by type" do
    filter = build_filter({ str: "abc", int: "42", flt: "1.5", date: "2026-01-02", bool: "true" }) do
      filter_by :str, :string
      filter_by :int, :integer
      filter_by :flt, :float
      filter_by :date, :date
      filter_by :bool, :boolean
    end

    assert_equal "abc", filter.str
    assert_equal 42, filter.int
    assert_in_delta 1.5, filter.flt
    assert_equal Date.new(2026, 1, 2), filter.date
    assert_equal true, filter.bool
  end

  test "blank params are unset" do
    filter = build_filter({ str: "", int: "", date: "", bool: "", list: [] }) do
      filter_by :str, :string
      filter_by :int, :integer
      filter_by :date, :date
      filter_by :bool, :boolean
      filter_by :list, :integer
    end

    [:str, :int, :date, :bool, :list].each do |name|
      assert_nil filter.public_send(name), "expected #{name} to be unset"
      assert_not filter.applied?(name), "expected #{name} not to be applied"
      assert_not filter.active?(name), "expected #{name} not to be active"
    end
    assert_not filter.active?
  end

  test "uncastable values are unset instead of raising or filtering for garbage" do
    filter = build_filter({ date: "xxx", int: "abc" }) do
      filter_by :date, :date
      filter_by :int, :integer
    end

    assert_nil filter.date
    assert_nil filter.int
  end

  test "array values drop blank members and an all-blank array is unset" do
    filter = build_filter({ some: ["", "3", "7"], none: ["", ""] }) do
      filter_by :some, :integer
      filter_by :none, :integer
    end

    assert_equal [3, 7], filter.some
    assert_nil filter.none
  end

  # --- boolean vs flag -------------------------------------------------------

  test "boolean is tri-state: false is a value that filters" do
    off = build_filter({ published: "0" }) { filter_by :published, :boolean }
    on = build_filter({ published: "1" }) { filter_by :published, :boolean }
    unset = build_filter({}) { filter_by :published, :boolean }

    assert_equal false, off.published
    assert off.applied?(:published)
    assert off.active?(:published)

    assert_equal true, on.published
    assert on.applied?(:published)

    assert_nil unset.published
    assert_not unset.applied?(:published)
  end

  test "flag treats false like unset, so an unchecked checkbox stops filtering" do
    off = build_filter({ archived: "0" }) { filter_by :archived, :flag }
    on = build_filter({ archived: "1" }) { filter_by :archived, :flag }

    assert_nil off.archived
    assert_not off.applied?(:archived)
    assert_not off.active?(:archived)

    assert_equal true, on.archived
    assert on.applied?(:archived)
    assert on.active?(:archived)
  end

  test "flag with a false default stays unset" do
    filter = build_filter({}) { filter_by :archived, :flag, default: false }

    assert_nil filter.archived
    assert_not filter.applied?(:archived)
  end

  # --- defaults --------------------------------------------------------------

  test "the default fills in for an unset param but is not active" do
    filter = build_filter({}) { filter_by :range, :string, default: "all" }

    assert_equal "all", filter.range
    assert filter.applied?(:range), "a default value is still applied, so blocks must handle it"
    assert_not filter.active?(:range)
    assert_not filter.active?
  end

  test "a param equal to the default is applied but not active" do
    filter = build_filter({ range: "all" }) { filter_by :range, :string, default: "all" }

    assert filter.applied?(:range)
    assert_not filter.active?(:range)
  end

  test "a param differing from the default is active" do
    filter = build_filter({ range: "past" }) { filter_by :range, :string, default: "all" }

    assert_equal "past", filter.range
    assert filter.active?(:range)
    assert filter.active?
  end

  test "a blank param falls back to the default" do
    filter = build_filter({ range: "" }) { filter_by :range, :string, default: "all" }

    assert_equal "all", filter.range
    assert_not filter.active?(:range)
  end

  # --- applying --------------------------------------------------------------

  test "only applied filters run their block, and blocks never see nil" do
    filter = build_filter({ set: "x", blank: "", flag_off: "0" }) do
      filter_by :set, :string do |arel, value|
        arel + ["set:#{value}"]
      end
      filter_by :blank, :string do |arel, value|
        arel + ["blank:#{value}"]
      end
      filter_by :flag_off, :flag do |arel, _value|
        arel + ["flag_off"]
      end
      filter_by :defaulted, :string, default: "all" do |arel, value|
        arel + ["defaulted:#{value}"]
      end
    end

    assert_equal ["set:x", "defaulted:all"], filter.filter([])
  end

  test "a block returning nil leaves the relation untouched" do
    filter = build_filter({ noop: "x" }) do
      filter_by :noop, :string do |_arel, _value|
        nil
      end
    end

    assert_equal ["untouched"], filter.filter(["untouched"])
  end

  test "a filter without a block only carries its value" do
    filter = build_filter({ flag: "1" }) { filter_by :flag, :flag }

    assert_equal true, filter.flag
    assert_equal [], filter.filter([])
  end

  # --- context isolation -----------------------------------------------------

  test "filter names do not leak between contexts" do
    build_filter({}) { filter_by :only_here, :string }
    other = build_filter({}) { filter_by :elsewhere, :string }

    assert_respond_to other, :elsewhere
    assert_not_respond_to other, :only_here
  end

  test "unknown types are rejected when the filter is defined" do
    assert_raises(ArgumentError) do
      build_filter({}) { filter_by :nope, :something_else }
    end
  end

  # --- session hygiene -------------------------------------------------------

  test "storable_params keeps only known keys that carry a value" do
    context = Filterable::FilterContext.new
    context.instance_eval do
      filter_by :title, :string
      filter_by :published, :boolean
      filter_by :archived, :flag
      filter_by :from_date, :date
      filter_by :topics, :integer
    end

    stored = context.storable_params(
      "title" => "ruby",
      "published" => "false",
      "archived" => "0",
      "from_date" => "xxx",
      "topics" => ["", "3"],
      "junk" => "x" * 100
    )

    assert_equal({ "title" => "ruby", "published" => "false", "topics" => ["", "3"] }, stored)
  end

  # --- the regression this rework came from ----------------------------------

  test "unchecking a flag next to another filter stops filtering by it" do
    checked = build_filter({ scope: "courses", with_upcoming_events: "1" }, &offers_definitions)
    unchecked = build_filter({ scope: "courses", with_upcoming_events: "0" }, &offers_definitions)

    assert_equal ["scope:courses", "upcoming"], checked.filter([])
    assert_equal ["scope:courses"], unchecked.filter([])
  end

  def offers_definitions
    proc do
      filter_by :scope, :string do |arel, scope|
        arel + ["scope:#{scope}"]
      end
      filter_by :with_upcoming_events, :flag do |arel, _value|
        arel + ["upcoming"]
      end
    end
  end

end
