module Admin
  # The filters of the event lists: the global one and the one of an offer.
  # Requires Filterable in the including controller.
  module EventFilter

    extend ActiveSupport::Concern

    included do
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
          arel.where(date_and_time: from_date.beginning_of_day..)
        end

        filter_by :to_date, :date do |arel, to_date|
          arel.where(date_and_time: ..to_date.end_of_day)
        end
      end
    end

    private

    # Applies the filters stored for this list to the given events.
    def filtered_events(scope)
      @filter = create_filter(:events)
      @filter.filter(scope)
    end

  end
end
