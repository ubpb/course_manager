module Admin
  class EventsController < ApplicationController

    include Filterable

    before_action -> { add_breadcrumb "Termine", admin_events_path }

    define_filter :events do
      filter_by :upcoming_or_past, :string, default: "all" do |arel, value|
        case value
        when "all"
          arel
        when "upcoming"
          arel.upcoming.reorder(date_and_time: :asc)
        when "upcoming_and_last_3_months"
          arel.upcoming_and_last_3_months.reorder(date_and_time: :asc)
        when "past"
          arel.past
        end
      end

      filter_by :published, :boolean, default: nil do |arel, published|
        arel.where(published: published)
      end

      filter_by :online, :boolean, default: nil do |arel, online|
        arel.where(online: online)
      end

      filter_by :delivery_format, :integer, default: nil do |arel, delivery_format_id|
        arel.where(delivery_format_id: delivery_format_id)
      end

      filter_by :with_report, :boolean, default: nil do |arel, with_report|
        if with_report == true
          arel.with_report
        elsif with_report == false
          arel.without_report
        end
      end

      filter_by :title, :string do |arel, title|
        arel.joins(:offer).where("offers.title like ?", "%#{ApplicationRecord.sanitize_sql_like(title)}%")
      end

      filter_by :from_date, :date do |arel, from_date|
        arel.where("date_and_time >= ?", from_date.beginning_of_day)
      end

      filter_by :to_date, :date do |arel, to_date|
        arel.where("date_and_time <= ?", to_date.end_of_day)
      end
    end

    def index
      load_events
      setup_bulk_process_actions(@events)
    end

    def bulk_process
      events = Event.where(id: params[:bulk_process_ids])

      case params[:bulk_process_action]
      when "publish"
        events.update_all(published: true)
        flash[:success] = "Termin(e) wurde(n) veröffentlicht"
      when "unpublish"
        events.update_all(published: false)
        flash[:success] = "Veröffentlichung von Termin(en) wurde zurückgezogen"
      when "move_to_offer"
        if events.none?
          flash[:alert] = "Bitte mindestens einen Termin auswählen"
        else
          render turbo_stream: turbo_stream.replace(
            "bulk-action-form",
            partial: "bulk_action_move_to_offer",
            locals: {
              events: events.includes(:offer),
              offers: Offer.courses.order(:title),
              url: bulk_move_admin_events_path,
              cancel_url: admin_events_path,
              container_id: "bulk-action-form"
            }
          )
          return
        end
      end

      redirect_to admin_events_path
    end

    def bulk_move
      events = Event.where(id: params[:event_ids])
      offer = Offer.courses.find_by(id: params[:target_offer_id])

      if offer.nil? || events.none?
        flash[:alert] = "Bitte Termine und Ziel-Angebot auswählen"
      else
        events.update_all(offer_id: offer.id)
        flash[:success] = "Termin(e) wurde(n) nach \"#{offer.title}\" verschoben"
      end

      redirect_to admin_events_path
    end

    def reports
      @reports = load_events.with_report.map(&:report)

      if @filter&.active?
        @from_date = @filter.from_date
        @to_date = @filter.to_date
      end

      respond_to do |format|
        format.xlsx do
          filename = [
            @from_date ? I18n.l(@from_date, format: "%Y-%m-%d") : nil,
            @to_date ? I18n.l(@to_date, format: "%Y-%m-%d") : nil,
            "report"
          ].compact.join("_")

          response.headers["Content-Disposition"] = "attachment; filename=\"#{filename}.xlsx\""

          render "admin/offers/events/reports/show"
        end
      end
    end

    private

    def setup_bulk_process_actions(events)
      @bulk_process_actions = []
      return if events.empty?

      @bulk_process_actions << ["Veröffentlichen", "publish"]
      @bulk_process_actions << ["Veröffentlichung zurückziehen", "unpublish"]
      @bulk_process_actions << ["In anderes Angebot verschieben", "move_to_offer"]
    end

    def load_events
      @events = Event.includes(:offer, :report).order(date_and_time: :desc)

      @filter = create_filter(:events) or return
      @events = @filter.filter(@events)
    end

  end
end
