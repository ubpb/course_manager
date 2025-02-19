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
        if v[:options][:array]
          self.class.attribute(k, default: v[:default].presence || [], **v[:options])
        else
          self.class.attribute(k, v[:cast_type], default: v[:default], **v[:options])
        end
      end

      super() # important to make ActiveModel::Attributes work

      # Set the values from the given filter attributes
      @context.filters.each do |k, v|
        filter_value = filter_attributes[k]

        # If the value is an array, cast each element to the correct type
        # and remove nil values.
        if filter_value.is_a?(Array)
          filter_value = filter_value.map(&:presence).compact.map do |fv|
            case v[:cast_type]
            when :string  then fv.to_s
            when :integer then fv.to_i
            when :float   then fv.to_f
            when :boolean then fv == "true"
            else fv
            end
          end
        end

        # Set the value if the attribute exists
        send("#{k}=", filter_value) if respond_to?("#{k}=")
      end
    end

    def active?
      @context.filters.keys.any? do |k|
        !filter_value(k).nil?
      end
    end

    def filter(arel)
      @context.filters.each do |k, v|
        filter_value = filter_value(k)
        next if filter_value.nil?

        callable = v[:block]
        next unless callable

        result = callable.call(arel, filter_value)
        arel = result if result
      end

      arel
    end

    private

    def filter_value(name)
      v = send(name)
      v&.in?([true, false]) ? v : v.presence
    end

  end

end
