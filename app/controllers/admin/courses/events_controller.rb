module Admin
  module Courses
    class EventsController < ApplicationController

      before_action -> { add_breadcrumb "Kurse", admin_courses_path }
      before_action :load_course
      before_action -> { add_breadcrumb "Termine", admin_course_events_path(@course) }
      before_action :load_event, only: [:edit, :update, :destroy, :duplicate]

      def index
        @events = @course.events.order("date_and_time")
      end

      def new
        @event = @course.events.build
      end

      def create
        @event = @course.events.build(event_params)

        if @event.save
          redirect_to admin_course_events_path(@course), notice: t("admin.application.form.success")
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit; end

      def update
        if @event.update(event_params)
          redirect_to admin_course_events_path(@course), notice: t("admin.application.form.success")
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @event.destroy
        redirect_to admin_course_events_path(@course)
      end

      def duplicate
        @event = @course.events.find(params[:id]).dup
        @event.registrations_count = 0
        @event.published = false
        @event.date_and_time = nil

        render :new
      end

      private

      def load_course
        @course = Course.includes(:events).find(params[:course_id])
        add_breadcrumb @course.title, admin_courses_path(anchor: helpers.dom_id(@course))
      end

      def load_event
        @event = Event.find(params[:id])
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
