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
    end

    def index
      @offers = Offer.order("title")

      @filter = create_filter(:offers) or return
      @offers = @filter.filter(@offers)
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

    def preview_reminder_message
      event = Event.new(
        offer: @offer,
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

    def offer_params
      params.require(:offer).permit(
        :type, :title, :description, :learning_targets, :reminder_message,
        :email_from, :published, :contact_name, :contact_email, :contact_phone,
        topic_ids: [], target_group_ids: []
      )
    end

  end
end
