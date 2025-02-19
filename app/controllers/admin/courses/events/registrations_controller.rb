module Admin
  module Courses
    module Events
      class RegistrationsController < ApplicationController

        before_action :prepare_course_event_registration_context

        def index
          @registrations = @event.registrations.order(last_name: :asc, first_name: :asc)

          respond_to do |format|
            format.html do
              setup_bulk_process_actions(@registrations)
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

        def send_certificate
          registration = @event.registrations.includes(event: [:course, :certification]).find(params[:id])
          send_certificate!(registration)

          flash[:success] = "Zertifikat wurde versendet"
          redirect_to admin_course_event_registrations_path(@course, @event)
        end

        def send_reminder_message
          registration = @event.registrations.includes(event: [:course]).find(params[:id])
          send_reminder_message!(registration, skip_if_sent: false)

          flash[:success] = "Erinnerungsmail wurde versendet"
          redirect_to admin_course_event_registrations_path(@course, @event)
        end

        def bulk_process
          registrations = @event.registrations
                                .includes(event: [:course, :certification])
                                .where(id: params[:bulk_process_ids])
          action = params[:bulk_process_action]

          case action
          when "send_certificates"
            send_certificates!(registrations)
            flash[:success] = "Zertifikat(e) wurde versendet"
          when "send_reminder_messages"
            send_reminder_messages!(registrations)
            flash[:success] = "Erinnerungsmail(s) wurde versendet"
          when "force_send_reminder_messages"
            send_reminder_messages!(registrations, skip_if_sent: false)
            flash[:success] = "Erinnerungsmail(s) wurde versendet"
          when "send_message"
            render turbo_stream: turbo_stream.replace(
              "bulk-action-form",
              partial: "bulk_action_new_message",
              locals: {
                course: @course,
                event: @event,
                registrations: registrations,
                message: Message.new
              }
            )
            return
          end

          redirect_to admin_course_event_registrations_path(@course, @event)
        end

        def send_message
          registrations = @event.registrations
                                .includes(event: [:course, :certification])
                                .where(id: params[:registration_ids])

          message_params = params.require(:message).permit(:subject, :body)
          message = Message.new(message_params)

          if message.valid?
            registrations.each do |registration|
              Admin::Mailers::RegistrationsMailer.user_message(registration, message).deliver
            end

            flash[:success] = "Nachricht gesendet"
            redirect_to admin_course_event_registrations_path(@course, @event)
          else
            render turbo_stream: turbo_stream.replace(
              "bulk-action-form",
              partial: "bulk_action_new_message",
              locals: {
                course: @course,
                event: @event,
                registrations: registrations,
                message: message
              }
            )
          end
        end

        private

        def setup_bulk_process_actions(registrations)
          @bulk_process_actions = []
          return if registrations.empty?

          if @event.certification.present?
            @bulk_process_actions << ["Zertifikat per Mail senden", "send_certificates"]
          end

          if @event.effective_reminder_message.present?
            @bulk_process_actions << ["Erinnerungsmail senden", "send_reminder_messages"]
            @bulk_process_actions << ["Erinnerungsmail ERNEUT senden", "force_send_reminder_messages"]
          end

          @bulk_process_actions << ["Nachricht schreiben", "send_message"]
        end

        def registration_params
          params.require(:registration).permit(
            :first_name, :last_name, :email, :field_of_interest, :user_notes, :internal_notes
          )
        end

        def send_certificate!(registration)
          Admin::Mailers::RegistrationsMailer.certificate(
            registration,
            Certificate.generate(registration),
            Certificate.filename(registration)
          ).deliver_later

          registration.update(certificate_sent_at: Time.zone.now)
        end

        def send_certificates!(registrations)
          registrations.each do |registration|
            send_certificate!(registration)
          end
        end

        def send_reminder_message!(registration, skip_if_sent: true)
          return if registration.reminder_message_sent_at.present? && skip_if_sent

          Admin::Mailers::EventsMailer.reminder_message(
            registration,
            skip_if_sent: skip_if_sent
          ).deliver_later

          registration.update(reminder_message_sent_at: Time.zone.now)
        end

        def send_reminder_messages!(registrations, skip_if_sent: true)
          registrations.each do |registration|
            send_reminder_message!(registration, skip_if_sent: skip_if_sent)
          end
        end

      end
    end
  end
end
