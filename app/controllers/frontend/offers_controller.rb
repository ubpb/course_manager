module Frontend
  class OffersController < ApplicationController

    include Filterable

    before_action :prepare_offer_context, except: [:redirect_courses, :redirect_consultings, :redirect_events]

    define_filter :offers do
      filter_by :scope, :string do |arel, scope|
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

      filter_by :with_upcoming_events, :boolean do |arel, _with_upcoming_events, options|
        arel.where(id: Event.published.upcoming.select(:offer_id))
        # ... reorder offers by event date and time instead of title
        # arel.joins(:events)
        #     .merge(Event.published.upcoming)
        #     .select("offers.*", "MIN(events.date_and_time) AS next_event_at")
        #     .group("offers.id")
        #     .reorder("next_event_at ASC", "offers.title ASC")
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
      @offers = Offer.published
                     .not_archived
                     .includes(:upcoming_events)
                     .order(title: :asc)

      # If the scope filter is not "courses", we ignore the with_upcoming_events filter
      # because events are only relevant for courses.
      params[:filter][:with_upcoming_events] = nil if params[:filter] && params[:filter][:scope] != "courses"

      @filter = create_filter(:offers)
      return unless @filter

      @offers = @filter.filter(@offers)
    end

    def show
      # The @offer instance variable is set in the prepare_offer_context before_action.
      @upcoming_events = @offer.events.published.upcoming.order(date_and_time: :asc)
    end

    def redirect_courses
      course = Offer.courses.find_by(old_id: params[:id]) if params[:id].present?

      if course
        redirect_to frontend_offer_path(course), status: :moved_permanently
      else
        redirect_to frontend_offers_path(filter: {scope: "courses"}), status: :moved_permanently
      end
    end

    def redirect_consultings
      consulting = Offer.consultings.find_by(old_id: params[:id]) if params[:id].present?

      if consulting
        redirect_to frontend_offer_path(consulting), status: :moved_permanently
      else
        redirect_to frontend_offers_path(filter: {scope: "consultings"}), status: :moved_permanently
      end
    end

    def redirect_events
      event = Event.find_by(id: params[:id]) if params[:id].present?

      if event
        redirect_to frontend_offer_path(event.offer), status: :moved_permanently
      else
        redirect_to frontend_offers_path(filter: {scope: "courses", with_upcoming_events: true}), status: :moved_permanently
      end
    end

  end
end
