module Admin
  module Offers
    module Events
      class CertificationsController < ApplicationController

        before_action :prepare_offer_event_certification_context

        def show
          if @certification
            redirect_to edit_admin_offer_event_certification_path(@offer, @event)
          else
            redirect_to new_admin_offer_event_certification_path(@offer, @event)
          end
        end

        def new
          if @certification
            redirect_to edit_admin_offer_event_certification_path(@offer, @event)
          else
            @certification = @event.build_certification
          end
        end

        def create
          @certification = @event.build_certification(certification_params)

          if @certification.save
            redirect_to edit_admin_offer_event_certification_path(@offer, @event, @certification), notice: t("admin.application.form.success")
          else
            render :new, status: :unprocessable_entity
          end
        end

        def edit; end

        def update
          if @certification.update(certification_params)
            redirect_to edit_admin_offer_event_certification_path(@offer, @event, @certification), notice: t("admin.application.form.success")
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
