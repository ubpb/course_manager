module Admin
  module Courses
    module Events
      class ReportsController < EventsController

        before_action :load_report

        def show
          if @report
            respond_to do |format|
              format.html do
                redirect_to edit_admin_course_event_report_path(@course, @event)
              end

              format.xlsx do
                filename = [
                  I18n.l(@event.date_and_time.to_date, format: "%Y-%m-%d").parameterize,
                  I18n.l(@event.date_and_time.to_time, format: "%H-%M").parameterize,
                  @course.title.parameterize,
                  "report"
                ].join("_")

                response.headers["Content-Disposition"] = "attachment; filename=\"#{filename}.xlsx\""
              end
            end
          else
            redirect_to new_admin_course_event_report_path(@course, @event)
          end
        end

        def new
          if @report
            redirect_to edit_admin_course_event_report_path(@course, @event)
          else
            @report = @event.build_report
          end
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
          @report = @event.report
          add_breadcrumb "Statistik", admin_course_event_report_path(@course, @event)
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
