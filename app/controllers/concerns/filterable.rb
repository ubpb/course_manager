# Filtering for index pages.
#
# A controller declares its filters once:
#
#   define_filter :offers do
#     filter_by :scope, :string do |arel, scope| ... end
#     filter_by :with_upcoming_events, :flag do |arel, _value| ... end
#   end
#
#   before_action -> { persist_filter_params(:offers) }, only: :index
#
#   def index
#     @filter = create_filter(:offers)
#     @offers = @filter.filter(Offer.all)
#   end
#
# Filter values are persisted in the session per controller path, so a list keeps
# its filtering while the user navigates. `?filter[...]=` sets them and
# `?reset_filter=1` clears them; both redirect to the clean list URL (PRG).
#
# Value semantics -- one rule, used by casting, `#filter` and `#active?`:
#
#   unset    A raw param that is nil, blank or uncastable (e.g. "abc" as a date).
#            Array filters drop blank members first, an empty array is unset.
#   default  The value used when a filter is unset. Purely the initial state of
#            the form; a filter holding its default IS applied, so its block must
#            handle the default value (e.g. "all" -> return arel unchanged).
#   applied  Value is not nil -> the block runs. Blocks never see nil.
#   active   Applied and different from the default -> worth showing as a chip.
#
# Types: :string, :integer, :float, :date, :boolean, :flag.
#
#   :boolean  Tri-state (nil / true / false), for a "Ja / Nein / egal" select.
#             `false` is a real value and filters for "Nein".
#   :flag     A checkbox, where only "on" carries meaning. `false` -- which is
#             what an unchecked checkbox submits as "0" -- is unset, so the block
#             does not run and no chip is shown.
module Filterable

  extend ActiveSupport::Concern

  included do
    class_attribute :filter_contexts, instance_writer: false, default: {}.with_indifferent_access
  end

  class_methods do
    def define_filter(name, &block)
      filter_context = FilterContext.new
      filter_context.instance_eval(&block) if block_given?

      # Assign instead of mutating: `class_attribute` shares its default between
      # all including classes, and a subclass must not write into its parent.
      self.filter_contexts = filter_contexts.merge(name => filter_context)
    end
  end

  private

  # Persists incoming filter params in the session and redirects to the clean
  # list URL. Declare as a `before_action` so the action never runs on a request
  # that is about to be redirected.
  def persist_filter_params(context_name,
                            filter_param: :filter,
                            reset_filter_param: :reset_filter,
                            path: request.path)
    context = filter_context!(context_name)

    if params[reset_filter_param].present?
      session.delete(filter_session_key)
      return redirect_to(path)
    end

    raw = params[filter_param]
    return unless raw.respond_to?(:to_unsafe_h)

    stored = context.storable_params(raw.to_unsafe_h)

    if stored.present?
      session[filter_session_key] = stored
    else
      session.delete(filter_session_key)
    end

    redirect_to(path)
  end

  def create_filter(context_name)
    Filter.new(filter_context: filter_context!(context_name),
               filter_params: session[filter_session_key] || {})
  end

  def filter_session_key
    "#{controller_path}/filter"
  end

  def filter_context!(context_name)
    self.class.filter_contexts[context_name] ||
      raise(ArgumentError, "unknown filter context #{context_name.inspect}")
  end

  # A single filter: how to cast its value and how to apply it to a relation.
  class Definition

    CASTERS = {
      string: ActiveModel::Type::String.new,
      float: ActiveModel::Type::Float.new,
      date: ActiveModel::Type::Date.new,
      boolean: ActiveModel::Type::Boolean.new
    }.freeze

    TYPES = (CASTERS.keys + [:integer, :flag]).freeze

    attr_reader :name, :type, :default, :block

    def initialize(name:, type:, default:, block:)
      raise ArgumentError, "unknown filter type #{type.inspect}" unless TYPES.include?(type)

      @name = name
      @type = type
      @default = default
      @block = block
    end

    # The value a filter holds for the given raw param: the cast param, or the
    # cast default when the param is unset.
    def value_from(raw)
      value = cast(raw)
      value.nil? ? default_value : value
    end

    def default_value
      cast(@default)
    end

    # nil for anything unset: nil, a blank string, an empty (or all-blank)
    # array, an uncastable value, and `false` for a :flag.
    def cast(value)
      return value.filter_map { |v| cast_one(v) }.presence if value.is_a?(Array)

      cast_one(value)
    end

    private

    def cast_one(value)
      return if value.nil?
      return if value.respond_to?(:empty?) && value.empty?

      case @type
      when :integer
        # Rails' integer cast turns "abc" into 0, which would silently filter for id 0.
        Integer(value, exception: false)
      when :flag
        true if CASTERS[:boolean].cast(value)
      else
        CASTERS.fetch(@type).cast(value)
      end
    end

  end

  class FilterContext

    def filter_by(name, type = :string, default: nil, &block)
      filters[name] = Definition.new(name: name, type: type, default: default, block: block)
    end

    def filters
      @filters ||= {}.with_indifferent_access
    end

    # The subset of a raw filter param hash worth persisting: known keys whose
    # value actually casts to something. Keeps unset values and unrelated keys
    # out of the (cookie-backed) session.
    def storable_params(raw_params)
      raw_params.slice(*filters.keys.map(&:to_s)).select do |name, value|
        !filters[name].cast(value).nil?
      end
    end

  end

  class Filter

    include ActiveModel::Model

    attr_reader :context, :params

    def initialize(filter_context:, filter_params: {})
      @context = filter_context
      @params = filter_params.with_indifferent_access

      # On the singleton class, so filter names stay scoped to this context
      # instead of accumulating on the shared Filter class.
      singleton_class.attr_accessor(*@context.filters.keys)

      super()

      @context.filters.each do |name, definition|
        send("#{name}=", definition.value_from(@params[name]))
      end
    end

    # Applied filters narrow the relation; their block receives the value.
    def applied?(name)
      !send(name).nil?
    end

    # Active filters deviate from their default and are shown as removable chips.
    # Without an argument: is any filter active?
    def active?(name = nil)
      return @context.filters.each_key.any? { |n| active?(n) } if name.nil?

      applied?(name) && send(name) != @context.filters.fetch(name).default_value
    end

    def filter(arel)
      @context.filters.each do |name, definition|
        next unless applied?(name) && definition.block

        result = definition.block.call(arel, send(name))
        arel = result if result
      end

      arel
    end

  end

end
