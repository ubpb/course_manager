module Frontend
  class CoursesController < ApplicationController

    before_action :prepare_context

    def index
      @courses = Course.published.order(title: :asc)
    end

    def show
      @course = Course.find(params[:id])
      @upcoming_events = @course.events.upcoming.published.order(date_and_time: :asc)
    end

    private

    def prepare_context
      add_breadcrumb "Kurse", frontend_courses_path

      course_id = params[:id] || return
      @course = Course.includes(:events, :category).find(course_id)

      add_breadcrumb @course.title, frontend_course_path(@course)
    end

  end
end
