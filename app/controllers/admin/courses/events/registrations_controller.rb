module Admin
  module Courses
    module Events
      class RegistrationsController < ApplicationController

        before_action :prepare_course_event_registration_context

        def index
          @registrations = @event.registrations.order(last_name: :asc, first_name: :asc)

          respond_to do |format|
            format.html do
              @bulk_process_actions = []

              if @registrations.any? && @event.certification.present?
                @bulk_process_actions << ["Zertifikat per Mail senden", "send_cert_email"]
              end
            end

            format.xlsx do
              filename = [
                I18n.l(@event.date_and_time.to_date, format: "%Y-%m-%d").parameterize,
                I18n.l(@event.date_and_time.to_time, format: "%H-%M").parameterize,
                @course.title.parameterize
              ].join("_")

              response.headers["Content-Disposition"] = "attachment; filename=\"#{filename}.xlsx\""
            end
          end
        end

        def new
          @registration = @event.registrations.build
        end

        def create
          @registration = @event.registrations.build(registration_params)

          if @registration.save
            redirect_to edit_admin_course_event_registration_path(@course, @event, @registration), notice: t("admin.application.form.success")
          else
            render :new, status: :unprocessable_entity
          end
        end

        def edit
          @registration = @event.registrations.find(params[:id])
        end

        def update
          if @registration.update(registration_params)
            redirect_to edit_admin_course_event_registration_path(@course, @event, @registration), notice: t("admin.application.form.success")
          else
            render :edit, status: :unprocessable_entity
          end
        end

        def destroy
          @registration.destroy
          redirect_to admin_course_event_registrations_path(@course, @event), notice: t("admin.application.form.destroy_success")
        end

        def bulk_process
          registrations = @event.registrations.where(id: params[:bulk_process_ids])
          action = params[:bulk_process_action]

          case action
          when "send_cert_email" then bulk_process_send_certificate(registrations)
          end

          redirect_to admin_course_event_registrations_path(@course, @event)
        end

        def download_certificate
          if @event.certification.present?
            registration = @event.registrations.includes(event: [:course, :certification]).find(params[:id])

            send_data(
              Certificate.generate(registration),
              filename: Certificate.filename(registration),
              type: "application/pdf",
              disposition: "attachment"
            )
          else
            head :ok
          end
        end

        def email_certificate
          registration = @event.registrations.includes(event: [:course, :certification]).find(params[:id])
          send_certificate(registration)

          flash[:success] = "Zertifikat wurde versendet"
          redirect_to admin_course_event_registrations_path(@course, @event)
        end

        private

        def registration_params
          params.require(:registration).permit(
            :first_name, :last_name, :email, :field_of_interest, :user_notes, :internal_notes
          )
        end

        def send_certificate(registration)
          return if @event.certification.blank?

          Mailers::RegistrationsMailer.certificate(
            registration,
            Certificate.generate(registration),
            Certificate.filename(registration),
          ).deliver_later

          registration.update(certificate_sent_at: Time.zone.now)
        end

        def bulk_process_send_certificate(registrations)
          # binding.b
          registrations.each do |registration|
            # Send certificate
          end
        end

      end
    end
  end
end
