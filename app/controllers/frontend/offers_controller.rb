module Frontend
  class OffersController < ApplicationController

    include Filterable

    before_action :prepare_offers_context
    before_action :prepare_offer_context, only: [:show]

    define_filter :offers do
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
        arel.where("offers.title like ?", "%#{ApplicationRecord.sanitize_sql_like(title)}%")
      end

      filter_by :target_groups, :integer do |arel, target_group_ids|
        arel.joins(:target_groups).where("target_groups.id IN (?)", target_group_ids)
      end

      filter_by :topics, :integer do |arel, topic_ids|
        arel.joins(:topics).where("topics.id IN (?)", topic_ids)
      end
    end

    def index
      @offers = Offer.published.order(title: :asc)

      @filter = create_filter(:offers)
      return unless @filter

      @offers = @filter.filter(@offers)
    end

    def show
      # The @offer instance variable is set in the prepare_offer_context before_action.
      @upcoming_events = @offer.events.published.upcoming.order(date_and_time: :asc)
    end

  end
end
