module Filterable

  extend ActiveSupport::Concern

  def apply_filter(context_name, filter_param: :filter,
                   reset_filter_param: :reset_filter, path: request.path)
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
    Filter.new(filter_context, filter_params)
  end

  class_methods do
    def define_filter(name, &block)
      name = name.to_s

      filter_context = FilterContext.new
      filter_contexts[name] = filter_context

      filter_context.instance_eval(&block) if block_given?
    end

    def filter_contexts
      @filter_contexts ||= {}.with_indifferent_access
    end
  end

  class FilterContext

    def filter_by(name, cast_type = :string, default: nil, **options, &block)
      name = name.to_s

      filters[name] = {
        cast_type: cast_type,
        default: default,
        options: options,
        block: block
      }
    end

    def filters
      @filters ||= {}.with_indifferent_access
    end

  end

  class Filter

    include ActiveModel::Attributes

    def initialize(filter_context, filter_attributes = {})
      @context = filter_context

      @context.filters.each do |k, v|
        self.class.attribute(k, v[:cast_type], default: v[:default], **v[:options])
      end

      super() # important to make ActiveModel::Attributes work

      @context.filters.each do |k, v|
        filter_value = filter_attributes[k]
        filter_value = filter_value.presence if v[:cast_type] == :string

        send("#{k}=", filter_value) if respond_to?("#{k}=")
      end
    end

    def active?
      @context.filters.keys.any? { |k| !send(k).nil? }
    end

    def filter(arel)
      @context.filters.each do |k, v|
        filter_value = send(k)
        callable = v[:block]

        next if filter_value.blank?
        next unless callable

        result = callable.call(arel, filter_value)
        arel = result if result
      end

      arel
    end

  end

end
