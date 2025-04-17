module Frontend
  class CoursesController < ApplicationController

    before_action :prepare_course_context

    def index
      redirect_to frontend_offers_path(filter: {scope: "courses"})
    end

    def show
      @course = Course.find(params[:id])
      @upcoming_events = @course.events.upcoming.published.order(date_and_time: :asc)
    end

  end
end
