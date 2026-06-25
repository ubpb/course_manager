module Filterable

  extend ActiveSupport::Concern

  def create_filter(context_name,
                   filter_param: :filter,
                   reset_filter_param: :reset_filter,
                   path: request.path)
    session_key = "#{controller_path}/filter"

    if params[reset_filter_param].present?
      session.delete(session_key)
      redirect_to path and return
    end

    if params[filter_param].present?
      session[session_key] = params[filter_param]
      redirect_to path and return
    end

    filter_context = self.class.filter_contexts[context_name.to_s]
    return unless filter_context

    filter_params = session[session_key] || {}

    Filter.new(filter_context: filter_context, filter_params: filter_params)
  end

  class_methods do
    def define_filter(name, &block)
      filter_context = FilterContext.new
      filter_contexts[name] = filter_context

      filter_context.instance_eval(&block) if block_given?
    end

    def filter_contexts
      @filter_contexts ||= {}.with_indifferent_access
    end
  end

  class FilterContext

    def filter_by(name, type = :string, default: nil, &block)
      filters[name] = {
        type: type,
        default: default,
        block: block
      }
    end

    def filters
      @filters ||= {}.with_indifferent_access
    end

  end

  class Filter

    include ActiveModel::Model

    def initialize(filter_context:, filter_params: {})
      # Store the filter context and params
      @context  = filter_context
      @params   = filter_params.with_indifferent_access

      # Create accessors for each filter
      @context.filters.each_key do |k|
        self.class.attr_accessor(k)
      end

      # Call super
      super()

      # For each filter configuration in the context set the filter value
      @context.filters.each do |name, filter|
        filter_value = if @params[name].is_a?(Array)
          @params[name].map do |value|
            cast_filter_value(value, type: filter[:type])
          end.compact
        else
          cast_filter_value(@params[name], type: filter[:type])
        end

        # Set the filter value to the default if it is nil
        default_value = cast_filter_value(filter[:default], type: filter[:type])
        filter_value = default_value if filter_value.nil?

        # Store the filter value
        send("#{name}=", filter_value)
      end
    end

    def active?
      @context.filters.any? do |name, filter|
        filter_value = send(name)
        filter_value = nil if filter_value.is_a?(Array) && filter_value.empty?

        default_value = cast_filter_value(filter[:default], type: filter[:type])

        !filter_value.nil? && filter_value != default_value
      end
    end

    def filter(arel, **options)
      @context.filters.each do |name, filter|
        filter_value = send(name)
        next if filter_value.blank?

        callable = filter[:block]
        next unless callable

        result = callable.call(arel, filter_value, options)
        arel = result if result
      end

      arel.distinct # Ensure distinct results to avoid duplicates
    end

    private

    def cast_filter_value(value, type:)
      value = value.presence
      return if value.nil?

      case type
      when :string
        value.to_s
      when :integer
        value.to_i
      when :float
        value.to_f
      when :date
        Date.parse(value)
      when :boolean
        ActiveModel::Type::Boolean.new.cast(value)
      else
        value
      end
    end

  end

end
