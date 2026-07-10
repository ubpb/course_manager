module Admin
  class OffersController < ApplicationController

    include Filterable

    before_action :prepare_offer_context

    define_filter :offers do
      filter_by :published, :boolean, default: nil do |arel, published|
        arel.where(published: published)
      end

      filter_by :scope, :string do |arel, scope|
        case scope
        when "courses"
          arel.courses
        when "consultings"
          arel.consultings
        else
          arel
        end
      end

      filter_by :title, :string do |arel, title|
        arel.where("title like ?", "%#{ApplicationRecord.sanitize_sql_like(title)}%")
      end

      filter_by :include_archived, :boolean, default: false
    end

    def index
      @offers = Offer.order("title")

      @filter = create_filter(:offers) or return
      @offers = @filter.filter(@offers)
      @offers = @offers.not_archived unless @filter.include_archived

      setup_bulk_process_actions(@offers)
    end

    def bulk_process
      offers = Offer.where(id: params[:bulk_process_ids])
      action = params[:bulk_process_action]

      case action
      when "archive"
        offers.update_all(archived: true)
        flash[:success] = "Angebot(e) wurde archiviert"
      end

      redirect_to admin_offers_path
    end

    def new
      @offer = Offer.new(type: "course")
    end

    def create
      @offer = Offer.new(offer_params)

      if @offer.save
        redirect_to edit_admin_offer_path(@offer), notice: t("admin.application.form.success")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @offer.update(offer_params)
        redirect_to edit_admin_offer_path(@offer), notice: t("admin.application.form.success")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @offer.destroy
      redirect_to admin_offers_path, notice: t("admin.application.form.destroy_success")
    end

    private

    def setup_bulk_process_actions(offers)
      @bulk_process_actions = []
      return if offers.empty?

      @bulk_process_actions << ["Archivieren", "archive"]
    end

    def offer_params
      params.require(:offer).permit(
        :type, :title, :description, :learning_targets,
        :published, :events_on_request, :call_to_action_url, :call_to_action_text,
        :contact_name, :contact_email, :contact_phone,
        topic_ids: [], target_group_ids: []
      )
    end

  end
end
