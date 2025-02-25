module Admin
  module Courses
    module Events
      class ReportsController < EventsController

        before_action :load_report

        def new
          redirect_to edit_admin_course_event_report_path(@course, @event) unless @report.new_record?
        end

        def create
          @report = @event.build_report(report_params)

          if @report.save
            redirect_to edit_admin_course_event_report_path(@course, @event, @report), notice: t("admin.application.form.success")
          else
            render :new, status: :unprocessable_entity
          end
        end

        def edit; end

        def update
          if @report.update(report_params)
            redirect_to edit_admin_course_event_report_path(@course, @event, @report), notice: t("admin.application.form.success")
          else
            render :edit, status: :unprocessable_entity
          end
        end

        private

        def load_report
          @report = @event.report || @event.build_report
          add_breadcrumb "Statistik", new_admin_course_event_report_path(@course, @event, @report)
        end

        def report_params
          params.require(:report).permit(
            :duration,
            :number_of_participants,
            :lecturer_md,
            :lecturer_gd,
            :lecturer_hd,
            :lecturer,
            :organization_types,
            :levels,
            :categories,
            :presence_types,
            forms: [],
            audiences: [],
            focus: []
          )
        end

      end
    end
  end
end
