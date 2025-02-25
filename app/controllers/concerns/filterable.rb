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

      filter_context = FilterContext.new(name)
      filter_contexts[name] = filter_context

      filter_context.instance_eval(&block)
    end

    def filter_contexts
      @filter_contexts ||= {}
    end
  end

  class FilterContext

    attr_reader :name, :filters

    def initialize(name)
      @name = name
      @filters = {}.with_indifferent_access
    end

    def filter_by(name, &block)
      name = name.to_s
      filters[name] = block
    end

  end

  class Filter

    def initialize(filter_context, filter_attributes = {})
      @context = filter_context

      @context.filters.each_key do |k|
        self.class.attr_accessor(k)
        send("#{k}=", filter_attributes[k].presence)
      end
    end

    def active?
      @context.filters.keys.any? { |k| send(k).present? }
    end

    def filter(arel)
      @context.filters.each do |name, callable|
        value = send(name)

        if value.present? && callable.respond_to?(:call)
          result = callable.call(arel, value)
          arel = result if result
        end
      end

      arel
    end

  end

end
