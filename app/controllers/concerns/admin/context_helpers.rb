module Admin
  module ContextHelpers

    extend ActiveSupport::Concern

    private

    def prepare_course_context
      add_breadcrumb "Kurse", admin_courses_path

      course_id = params[:course_id] || params[:id] || return
      @course = Course.includes(:events).find(course_id)

      add_breadcrumb @course.title, edit_admin_course_path(@course)
    end

    def prepare_course_event_context
      prepare_course_context

      add_breadcrumb "Termine", admin_course_events_path(@course)

      event_id = params[:event_id] || params[:id] || return
      @event = @course.events.includes(:report, :registrations).find(event_id)

      add_breadcrumb I18n.l(@event.date_and_time), edit_admin_course_event_path(@course, @event)
    end

    def prepare_course_event_registration_context
      prepare_course_event_context

      add_breadcrumb "Anmeldungen", admin_course_event_registrations_path(@course, @event)

      registration_id = params[:registration_id] || params[:id] || return
      @registration = @event.registrations.find(registration_id)

      add_breadcrumb @registration.full_name_reversed, edit_admin_course_event_path(@course, @event)
    end

    def prepare_course_event_report_context
      prepare_course_event_context

      @report = @event.report
      add_breadcrumb "Statistik", admin_course_event_report_path(@course, @event)
    end

    def prepare_course_event_certification_context
      prepare_course_event_context

      @certification = @event.certification
      add_breadcrumb "Zertifizierung", admin_course_event_report_path(@course, @event)
    end

  end
end
