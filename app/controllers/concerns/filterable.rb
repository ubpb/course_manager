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
# In a URL, each filter has a short name and value form, e.g.
# `?upcoming-or-past=upcoming&published=1&topics=3,5`:
#
#   param:    The name in the URL; the filter's name dasherized by default
#             (target_groups -> target-groups).
#   values:   The values a filter knows: a list, whose values appear dasherized,
#             or a hash of value -> URL form. Any other value in a URL is unset.
#   multiple: A list filter, written as a comma-separated list.
#
# Booleans appear as 1 / 0, a set flag as 1, dates as YYYY-MM-DD; unset values
# and defaults stay out of the URL.
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
    def define_filter(name, &)
      filter_context = FilterContext.new
      filter_context.instance_eval(&) if block_given?

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

    BOOLEAN_PARAMS = {"1" => "true", "0" => "false"}.freeze

    attr_reader :name, :type, :default, :block, :param

    def initialize(name:, type:, default:, block:, param: nil, values: nil, multiple: false)
      raise ArgumentError, "unknown filter type #{type.inspect}" unless TYPES.include?(type)

      @name = name
      @type = type
      @default = default
      @block = block
      @param = (param || name.to_s.dasherize).to_s
      @values = values.is_a?(Array) ? values.to_h { |v| [v.to_s, v.to_s.dasherize] } : values&.transform_keys(&:to_s)
      @multiple = multiple
    end

    # The URL form of a raw value; nil when it is unset or the default.
    def encode(raw)
      value = cast(raw)
      return if value.nil? || value == default_value
      return value.filter_map { |v| encode_one(v) }.join(",").presence if value.is_a?(Array)

      encode_one(value)
    end

    # The raw value of a URL param; nil for anything the filter does not know.
    def decode(value)
      return unless value.is_a?(String)
      return value.split(",").filter_map { |v| decode_one(v) } if @multiple

      decode_one(value)
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

    def encode_one(value)
      case value
      when true then "1"
      when false then "0"
      when Date then value.iso8601
      else @values ? @values[value.to_s] : value.to_s
      end
    end

    def decode_one(value)
      case @type
      when :boolean then BOOLEAN_PARAMS[value]
      when :flag then value if value == "1"
      else @values ? @values.key(value) : value
      end
    end

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

    RESERVED_PARAMS = ["filter", "reset_filter"].freeze

    def filter_by(name, type = :string, default: nil, param: nil, values: nil, multiple: false, &block)
      definition = Definition.new(name:, type:, default:, block:, param:, values:, multiple:)

      if RESERVED_PARAMS.include?(definition.param) || param_names.include?(definition.param)
        raise ArgumentError, "filter #{name.inspect} needs another URL name than #{definition.param.inspect}"
      end

      filters[name] = definition
    end

    def param_names
      filters.values.map(&:param)
    end

    # The raw filter params of the URL params that name a filter, by filter name.
    def decode(url_params)
      filters.each_value.with_object({}) do |definition, raw|
        raw[definition.name.to_s] = definition.decode(url_params[definition.param]) if url_params.key?(definition.param)
      end
    end

    # The canonical query of raw filter params: the set values in URL form, in
    # the order of the definitions, with commas left readable.
    def query(raw_params)
      raw_params = raw_params.with_indifferent_access

      filters.each_value.filter_map do |definition|
        value = definition.encode(raw_params[definition.name])
        "#{CGI.escape(definition.param)}=#{CGI.escape(value).gsub("%2C", ",")}" if value
      end.join("&")
    end

    def filters
      @filters ||= {}.with_indifferent_access
    end

    # The subset of a raw filter param hash worth persisting: known keys whose
    # value actually casts to something. Keeps unset values and unrelated keys
    # out of the (cookie-backed) session.
    def storable_params(raw_params)
      raw_params.slice(*filters.keys.map(&:to_s)).reject do |name, value|
        filters[name].cast(value).nil?
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

    def query
      @context.query(@params)
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
