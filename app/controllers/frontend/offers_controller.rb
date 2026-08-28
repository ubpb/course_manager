module Frontend
  class OffersController < ApplicationController

    include Filterable

    before_action :prepare_offer_context, except: [:redirect_courses, :redirect_consultings, :redirect_events]
    before_action -> { persist_filter_params(:offers) }, only: :index

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

      filter_by :with_upcoming_events, :flag do |arel, _with_upcoming_events|
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
        arel.joins(:target_groups).where("target_groups.id IN (?)", target_group_ids).distinct
      end

      filter_by :topics, :integer do |arel, topic_ids|
        arel.joins(:topics).where("topics.id IN (?)", topic_ids).distinct
      end
    end

    def index
      @offers = Offer.published
                     .not_archived
                     .includes(:upcoming_events)
                     .order(title: :asc)

      @filter = create_filter(:offers)

      # Events are only relevant for courses, so the with_upcoming_events filter is
      # ignored for any other scope (the form does not even render it there).
      @filter.with_upcoming_events = nil unless @filter.scope == "courses"

      @offers = @filter.filter(@offers)
    end

    def show
      # The @offer instance variable is set in the prepare_offer_context before_action.

      # Canonicalize the URL: /angebote/42 and outdated slugs (the title has changed
      # since the link was created) permanently redirect to the current slug URL.
      return redirect_to(frontend_offer_path(@offer), status: :moved_permanently) if params[:id] != @offer.to_param

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
