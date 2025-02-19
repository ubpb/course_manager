module Admin
  module Courses
    module Events
      class CertificationsController < ApplicationController

        before_action :prepare_course_event_certification_context

        def show
          if @certification
            redirect_to edit_admin_course_event_certification_path(@course, @event)
          else
            redirect_to new_admin_course_event_certification_path(@course, @event)
          end
        end

        def new
          if @certification
            redirect_to edit_admin_course_event_certification_path(@course, @event)
          else
            @certification = @event.build_certification
          end
        end

        def create
          @certification = @event.build_certification(certification_params)

          if @certification.save
            redirect_to edit_admin_course_event_certification_path(@course, @event, @certification), notice: t("admin.application.form.success")
          else
            render :new, status: :unprocessable_entity
          end
        end

        def edit; end

        def update
          if @certification.update(certification_params)
            redirect_to edit_admin_course_event_certification_path(@course, @event, @certification), notice: t("admin.application.form.success")
          else
            render :edit, status: :unprocessable_entity
          end
        end

        private

        def certification_params
          params.require(:certification).permit(
            :learning_results,
            :signature
          )
        end

      end
    end
  end
end
