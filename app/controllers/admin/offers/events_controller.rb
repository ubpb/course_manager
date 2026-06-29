module Admin
  module Offers
    class EventsController < ApplicationController

      before_action :prepare_offer_event_context

      def index
        @upcoming_events = @offer.events.upcoming.order(date_and_time: :asc)
        @past_events = @offer.events.past.order(date_and_time: :desc)
      end

      def new
        @event = @offer.events.build
      end

      def create
        @event = @offer.events.build(event_params)

        if @event.save
          redirect_to edit_admin_offer_event_path(@offer, @event), notice: t("admin.application.form.success")
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit; end

      def update
        @event.assign_attributes(event_params)

        if @event.valid?
          if @event.upcoming? && (@event.date_and_time_changed? || @event.location_changed?)
            @event.registrations.each do |registration|
              # Must be send with #deliver and not #deliver_later, because the event is saved afterwards
              # ans we need the changes to be present in the email
              Admin::Mailers::EventsMailer.changed_notification(@event, registration).deliver
            end
          end

          @event.save

          redirect_to edit_admin_offer_event_path(@offer, @event), notice: t("admin.application.form.success")
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @event.destroy

        flash[:notice] = t("admin.application.form.destroy_success")

        if nav_scope == "events"
          redirect_to admin_events_path(nav_scope: nil)
        else
          redirect_to admin_offer_events_path(@offer)
        end
      end

      def duplicate
        new_date_and_time = Time.zone.now
        new_date_and_time = new_date_and_time.change(sec: 0, usec: 0)

        event = @offer.events.find(params[:id]).dup
        event.registrations_count = 0
        event.published = false
        event.date_and_time = new_date_and_time
        event.save

        flash[:notice] = "Das Event wurde dupliziert und gespeichert. Datum und Uhrzeit wurden auf die aktuelle Zeit eingestellt. Bitte bearbeite die Details."
        redirect_to edit_admin_offer_event_path(@offer, event)
      end

      def preview_reminder_message
        event = @offer.events.find(params[:id])

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

      def event_params
        params.require(:event).permit(
          :date_and_time, :duration, :location, :reminder_message,
          :email_from, :online, :published, :registration_required,
          :max_no_of_participants
        )
      end

    end
  end
end
