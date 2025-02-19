module Admin
  class CoursesController < ApplicationController

    before_action -> { add_breadcrumb "Kurse", admin_courses_path }
    before_action :load_course, only: [:edit, :update, :destroy]

    def index
      @courses = Course.order("title").includes(:category)
    end

    def new
      @course = Course.new
    end

    def create
      @course = Course.new(course_params)

      if @course.save
        redirect_to admin_courses_path, notice: t("admin.application.form.success")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @course.update(course_params)
        redirect_to admin_course_path(@course), notice: t("admin.application.form.success")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @course.destroy
      redirect_to admin_courses_path
    end

    private

    def load_course
      @course = Course.find(params[:id])
      add_breadcrumb @course.title, edit_admin_course_path(params[:id])
    end

    def course_params
      params.require(:course).permit(
        :title, :description, :learning_targets, :reminder_message,
        :email_from, :published, :category_id, topic_ids: [], target_group_ids: []
      )
    end

  end
end
