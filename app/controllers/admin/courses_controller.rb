module Admin
  class CoursesController < ApplicationController

    include Filterable

    before_action :prepare_course_context

    define_filter :courses do
      filter_by :published, :boolean, default: nil do |arel, published|
        arel.where(published: published)
      end

      filter_by :title, :string do |arel, title|
        arel.where("title like ?", "%#{ApplicationRecord.sanitize_sql_like(title)}%")
      end

      filter_by :category, :integer do |arel, id|
        arel.where(category: id)
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
      redirect_to admin_courses_path, notice: t("admin.application.form.destroy_success")
    end

    def preview_reminder_message
      course = Course.find(params[:id])

      event = Event.new(
        course: course,
        date_and_time: Time.zone.now,
        duration: 60,
        location: "Raum 123"
      )

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

    def course_params
      params.require(:course).permit(
        :title, :description, :learning_targets, :reminder_message,
        :email_from, :published, :category_id, topic_ids: [], target_group_ids: []
      )
    end

  end
end
