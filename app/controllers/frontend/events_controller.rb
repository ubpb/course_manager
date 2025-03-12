module Frontend
  class EventsController < ApplicationController

    include Filterable

    before_action :prepare_context

    define_filter :events do
      filter_by :title, :string do |arel, title|
        arel.joins(:course).where("courses.title like ?", "%#{ApplicationRecord.sanitize_sql_like(title)}%")
      end

      filter_by :online, :boolean, default: nil do |arel, online|
        arel.where(online: online)
      end

      filter_by :date_range, :string do |arel, date_range|
        case date_range
        when "week"    then arel.where("date_and_time <= ?", 1.week.from_now.end_of_day)
        when "month"   then arel.where("date_and_time <= ?", 1.month.from_now.end_of_day)
        when "quarter" then arel.where("date_and_time <= ?", 3.months.from_now.end_of_day)
        end
      end

      filter_by :target_groups, :integer, array: true do |arel, target_group_ids|
        arel.joins(course: :target_groups).where("target_groups.id IN (?)", target_group_ids)
      end

      filter_by :topics, :integer, array: true do |arel, topic_ids|
        arel.joins(course: :topics).where("topics.id IN (?)", topic_ids)
      end
    end

    def index
      @upcoming_events = Event.published.upcoming.order(date_and_time: :asc)

      @filter = apply_filter(:events) or return
      @upcoming_events = @filter.filter(@upcoming_events)
    end

    def show
      @event = Event.published.upcoming.find(params[:id])
    end

    private

    def prepare_context
      add_breadcrumb "Termine", frontend_events_path

      event_id = params[:id] || return
      @event = Event.includes(:course).find(event_id)

      add_breadcrumb I18n.l(@event.date_and_time), frontend_event_path(@event)
    end

  end
end
