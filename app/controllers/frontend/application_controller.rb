module Frontend
  class ApplicationController < ::ApplicationController

    private

    def prepare_course_context
      add_breadcrumb "Schulungen", frontend_root_path
      add_breadcrumb "Kurse", frontend_courses_path

      course_id = params[:course_id] || params[:id] || return
      @course = Course.published.includes(:events, :category).find(course_id)

      add_breadcrumb @course.title, frontend_course_path(@course)
    end

    def prepare_event_context
      add_breadcrumb "Schulungen", frontend_root_path
      add_breadcrumb "Termine", frontend_events_path

      event_id = params[:event_id] || params[:id] || return
      @event = Event.published.includes(:course).find(event_id)

      add_breadcrumb I18n.l(@event.date_and_time), frontend_event_path(@event)
    end

    def prepare_consulting_context
      add_breadcrumb "Beratungen", frontend_consultings_path

      consulting_id = params[:consulting_id] || params[:id] || return
      @consulting = Consulting.published.find(consulting_id)

      add_breadcrumb @consulting.title, frontend_consulting_path(@consulting)
    end

  end
end
