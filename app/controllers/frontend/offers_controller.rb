module Frontend
  class OffersController < ApplicationController

    include Filterable

    before_action :prepare_offers_context

    define_filter :offers do
      filter_by :scope, :string do |arel, scope|
        arel
      end

      filter_by :title, :string do |arel, title, options|
        case options[:scope]
        when "courses"
          arel.where("courses.title like ?", "%#{ApplicationRecord.sanitize_sql_like(title)}%")
        when "consultings"
          arel.where("consultings.title like ?", "%#{ApplicationRecord.sanitize_sql_like(title)}%")
        end
      end

      filter_by :category, :integer do |arel, category_id|
        arel.where(category_id: category_id)
      end

      filter_by :target_groups, :integer do |arel, target_group_ids|
        arel.joins(:target_groups).where("target_groups.id IN (?)", target_group_ids)
      end

      filter_by :topics, :integer do |arel, topic_ids|
        arel.joins(:topics).where("topics.id IN (?)", topic_ids)
      end
    end

    def index
      courses = Course.published.order(title: :asc)
      consultings = Consulting.published.order(title: :asc)

      if (@filter = create_filter(:offers))
        courses = @filter.filter(courses, scope: "courses")
        consultings = @filter.filter(consultings, scope: "consultings")
      end

      @offers = case @filter&.scope
                when "courses"
                  @offers = courses.to_a
                when "consultings"
                  @offers = consultings.to_a
                else
                  courses.to_a + consultings.to_a
      end
    end

  end
end
