module Admin
  class CoursesController < ApplicationController

    include Filterable

    before_action :raise_if_action_is_inherited

    before_action -> { add_breadcrumb "Kurse", admin_courses_path }
    before_action :load_course

    define_filter :courses do
      filter_by :title do |arel, title|
        arel.where("title like ?", "%#{title}%") if title.present?
      end

      filter_by :category do |arel, id|
        arel.where(category: id) if id.present?
      end

      filter_by :published do |arel, published|
        arel.where(published: published) if published == true
      end
    end

    def index
      @courses = Course.order("title").includes(:category)

      @filter = apply_filter(:courses) or return
      @courses = @filter.filter(@courses)
    end

    def new
      @course = Course.new
    end

    def create
      @course = Course.new(course_params)

      if @course.save
        redirect_to edit_admin_course_path(@course), notice: t("admin.application.form.success")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @course.update(course_params)
        redirect_to edit_admin_course_path(@course), notice: t("admin.application.form.success")
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
      course_id = params[:course_id] || params[:id] || return

      @course = Course.includes(:events).find(course_id)
      add_breadcrumb @course.title, admin_courses_path(anchor: helpers.dom_id(@course))
    end

    def course_params
      params.require(:course).permit(
        :title, :description, :learning_targets, :reminder_message,
        :email_from, :published, :category_id, topic_ids: [], target_group_ids: []
      )
    end

  end
end
