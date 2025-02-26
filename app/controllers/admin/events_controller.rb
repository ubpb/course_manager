module Admin
  class EventsController < ApplicationController

    include Filterable

    before_action -> { add_breadcrumb "Termine", admin_events_path }

    define_filter :events do
      filter_by :published, :boolean, default: nil do |arel, published|
        arel.where(published: published)
      end

      filter_by :upcoming_or_past, :string do |arel, upcoming_or_past|
        if upcoming_or_past == "upcoming"
          arel.upcoming
        elsif upcoming_or_past == "past"
          arel.past
        end
      end

      filter_by :online, :boolean, default: nil do |arel, online|
        arel.where(online: online)
      end

      filter_by :with_report, :boolean, default: nil do |arel, with_report|
        if with_report == true
          arel.with_report
        elsif with_report == false
          arel.without_report
        end
      end

      filter_by :title, :string do |arel, title|
        arel.joins(:course).where("courses.title like ?", "%#{ApplicationRecord.sanitize_sql_like(title)}%")
      end

      filter_by :from_date, :date do |arel, from_date|
        arel.where("date_and_time >= ?", from_date.beginning_of_day)
      end

      filter_by :to_date, :date do |arel, to_date|
        arel.where("date_and_time <= ?", to_date.end_of_day)
      end
    end

    def index
      @events = Event.includes(:course, :report).order(date_and_time: :desc)

      @filter = apply_filter(:events) or return
      @events = @filter.filter(@events)
    end

  end
end
