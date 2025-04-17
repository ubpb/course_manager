module Admin
  class ConsultingsController < ApplicationController

    include Filterable

    before_action :prepare_consulting_context

    define_filter :consultings do
      filter_by :title, :string do |arel, title|
        arel.where("title like ?", "%#{ApplicationRecord.sanitize_sql_like(title)}%")
      end
    end

    def index
      @consultings = Consulting.includes(:category).order("title")

      @filter = create_filter(:consultings) or return
      @consultings = @filter.filter(@consultings)
    end

    def new
      @consulting = Consulting.new
    end

    def create
      @consulting = Consulting.new(consulting_params)

      if @consulting.save
        redirect_to edit_admin_consulting_path(@consulting), notice: t("admin.application.form.success")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @consulting.update(consulting_params)
        redirect_to edit_admin_consulting_path(@consulting), notice: t("admin.application.form.success")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @consulting.destroy
      redirect_to admin_consultings_path, notice: t("admin.application.form.destroy_success")
    end

    private

    def consulting_params
      params.require(:consulting).permit(
        :title,
        :description,
        :published,
        :contact_name,
        :contact_email,
        :contact_phone,
        :category_id,
        topic_ids: [],
        target_group_ids: []
      )
    end

  end
end
