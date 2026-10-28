module Admin
  class OffersController < ApplicationController

    include Filterable
    include ModalForm

    before_action :prepare_offer_context
    before_action -> { @offer_page = true }, only: [:edit, :update]
    before_action -> { add_breadcrumb "Angebotsdaten" }, only: [:edit, :update]
    before_action -> { add_breadcrumb "Neues Angebot" }, only: [:new, :create]
    before_action -> { canonicalize_filter_url(:offers) }, only: :index

    define_filter :offers do
      filter_by :published, :boolean, default: nil do |arel, published|
        arel.where(published: published)
      end

      filter_by :scope, :string, values: ["courses", "consultings", "self_study_courses"] do |arel, scope|
        case scope
        when "courses"
          arel.courses
        when "consultings"
          arel.consultings
        when "self_study_courses"
          arel.self_study_courses
        else
          arel
        end
      end

      filter_by :title, :string do |arel, title|
        arel.where("title like ?", "%#{ApplicationRecord.sanitize_sql_like(title)}%")
      end

      filter_by :include_archived, :flag
    end

    def index
      @offers = Offer.order(:title)

      @filter = create_filter(:offers)
      @offers = @filter.filter(@offers)
      @offers = @offers.not_archived unless @filter.include_archived

      setup_bulk_process_actions(@offers)
    end

    def bulk_process
      offers = Offer.where(id: params[:bulk_process_ids])
      action = params[:bulk_process_action]

      # The redirect below follows, so no flash.now (the cop misreads the case);
      # update_all on purpose for a bulk change of a plain flag.
      # rubocop:disable-next Rails/ActionControllerFlashBeforeRender, Rails/SkipsModelValidations
      case action
      when "archive"
        offers.update_all(archived: true)
        flash[:success] = "Angebot(e) wurde archiviert"
      end

      redirect_to admin_offers_path
    end

    def new
      @offer = Offer.new(type: "course")
      respond_with_modal(offer: @offer)
    end

    def edit; end

    def create
      @offer = Offer.new(offer_params)

      if @offer.save
        respond_with_list(admin_offers_path, notice: t("admin.application.form.success"))
      else
        respond_with_errors(:new, offer: @offer)
      end
    end

    def update
      if @offer.update(offer_params)
        redirect_to edit_admin_offer_path(@offer), notice: t("admin.application.form.success")
      else
        render :edit, status: :unprocessable_content
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
      params.expect(
        offer: [
          :type, :title, :description, :learning_targets,
          :published, :events_on_request, :call_to_action_url, :call_to_action_text,
          :contact_name, :contact_email, :contact_phone,
          {topic_ids: [], target_group_ids: []}
        ]
      )
    end

  end
end
