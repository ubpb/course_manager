module Admin
  module Courses
    class EventsController < ApplicationController

      before_action :prepare_course_event_context

      def index
        @upcoming_events = @course.events.upcoming.order(date_and_time: :asc)
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
        @event.assign_attributes(event_params)

        if @event.valid?
          if @event.upcoming? && (@event.date_and_time_changed? || @event.location_changed?)
            @event.registrations.each do |registration|
              # Must be send with #deliver and not #deliver_later, because the event is saved afterwards
              # ans we need the changes to be present in the email
              Admin::Mailers::EventsMailer.changed_notification(@event, registration).deliver
            end
          end

          @event.save

          redirect_to edit_admin_course_event_path(@course, @event), notice: t("admin.application.form.success")
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @event.destroy

        flash[:notice] = t("admin.application.form.destroy_success")

        if nav_scope == "events"
          redirect_to admin_events_path(nav_scope: nil)
        else
          redirect_to admin_course_events_path(@course)
        end
      end

      def duplicate
        new_date_and_time = Time.zone.now
        new_date_and_time = new_date_and_time.change(sec: 0, usec: 0)

        event = @course.events.find(params[:id]).dup
        event.registrations_count = 0
        event.published = false
        event.date_and_time = new_date_and_time
        event.save

        flash[:notice] = "Das Event wurde dupliziert und gespeichert. Datum und Uhrzeit wurden auf die aktuelle Zeit eingestellt. Bitte bearbeite die Details."
        redirect_to edit_admin_course_event_path(@course, event)
      end

      def preview_reminder_message
        event = @course.events.find(params[:id])

        registration = Registration.new(
          event: event,
          first_name: "Max",
          last_name: "Mustermann",
          email: "schulung@ub.uni-paderborn.de"
        )

        mail = Admin::Mailers::EventsMailer.reminder_message(registration, skip_if_sent: false)
        @preview = mail.body.to_s
      end

      private

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
