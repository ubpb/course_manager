module Admin
  module Courses
    class EventsController < CoursesController

      before_action -> { add_breadcrumb "Termine", admin_course_events_path(@course) }
      before_action :load_event

      def index
        @upcoming_events = @course.events.upcoming.order(date_and_time: :desc)
        @past_events = @course.events.past.order(date_and_time: :desc)
      end

      def new
        @event = @course.events.build
      end

      def create
        @event = @course.events.build(event_params)

        if @event.save
          redirect_to edit_admin_course_event_path(@course, @event), notice: t("admin.application.form.success")
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit; end

      def update
        if @event.update(event_params)
          redirect_to edit_admin_course_event_path(@course, @event), notice: t("admin.application.form.success")
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @event.destroy
        redirect_to admin_course_events_path(@course)
      end

      def duplicate
        event = @course.events.find(params[:id]).dup
        event.registrations_count = 0
        event.published = false
        event.date_and_time = Time.zone.now
        event.save

        flash[:notice] = "Das Event wurde dupliziert und gespeichert. Datum und Uhrzeit wurden auf die aktuelle Zeit eingestellt. Bitte bearbeite die Details."
        redirect_to edit_admin_course_event_path(@course, event)
      end

      private

      def load_event
        event_id = params[:event_id] || params[:id] || return

        @event = @course.events.includes(:report, :registrations).find(event_id)
        add_breadcrumb I18n.l(@event.date_and_time), edit_admin_course_event_path(@course, @event)
      end

      def event_params
        params.require(:event).permit(
          :date_and_time, :duration, :location, :reminder_message,
          :email_from, :online, :published, :registration_required,
          :max_no_of_participants
        )
      end

    end
  end
end
