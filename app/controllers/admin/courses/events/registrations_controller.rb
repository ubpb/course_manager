module Admin
  module Courses
    module Events
      class RegistrationsController < EventsController

        before_action -> { add_breadcrumb "Anmeldungen", admin_course_event_registrations_path(@course, @event) }
        before_action :load_registration

        def index
          @registrations = @event.registrations.order(last_name: :asc, first_name: :asc)

          respond_to do |format|
            format.html
            format.xlsx do
              filename = [
                I18n.l(@event.date_and_time.to_date, format: "%Y-%m-%d").parameterize,
                I18n.l(@event.date_and_time.to_time, format: "%H-%M").parameterize,
                @course.title.parameterize
              ].join("_")

              response.headers["Content-Disposition"] = "attachment; filename=\"#{filename}.xlsx\""
            end
          end
        end

        def new
          @registration = @event.registrations.build
        end

        def create
          @registration = @event.registrations.build(registration_params)

          if @registration.save
            redirect_to edit_admin_course_event_registration_path(@course, @event, @registration), notice: t("admin.application.form.success")
          else
            render :new, status: :unprocessable_entity
          end
        end

        def edit
          @registration = @event.registrations.find(params[:id])
        end

        def update
          if @registration.update(registration_params)
            redirect_to edit_admin_course_event_registration_path(@course, @event, @registration), notice: t("admin.application.form.success")
          else
            render :edit, status: :unprocessable_entity
          end
        end

        def destroy
          @registration.destroy
          redirect_to admin_course_event_registrations_path(@course, @event)
        end

        private

        def load_registration
          registration_id = params[:registration_id] || params[:id] || return

          @registration = @event.registrations.find(registration_id)
          add_breadcrumb @registration.full_name_reversed, edit_admin_course_event_path(@course, @event)
        end

        def registration_params
          params.require(:registration).permit(
            :first_name, :last_name, :email, :field_of_interest, :user_notes, :internal_notes
          )
        end

      end
    end
  end
end
