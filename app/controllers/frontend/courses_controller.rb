module Frontend
  class CoursesController < ApplicationController

    include Filterable

    before_action :prepare_course_context

    define_filter :courses do
      filter_by :title, :string do |arel, title|
        arel.where("courses.title like ?", "%#{ApplicationRecord.sanitize_sql_like(title)}%")
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
      @courses = Course.published.order(title: :asc).distinct

      @filter = apply_filter(:courses) or return
      @courses = @filter.filter(@courses)
    end

    def show
      @course = Course.find(params[:id])
      @upcoming_events = @course.events.upcoming.published.order(date_and_time: :asc)
    end

  end
end
