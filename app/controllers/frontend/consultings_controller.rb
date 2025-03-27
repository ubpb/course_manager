module Frontend
  class ConsultingsController < ApplicationController

    include Filterable

    before_action :prepare_consulting_context

    define_filter :consultings do
      filter_by :title, :string do |arel, title|
        arel.where("consultings.title like ?", "%#{ApplicationRecord.sanitize_sql_like(title)}%")
      end

      filter_by :category, :integer do |arel, category_id|
        arel.where(category_id: category_id)
      end

      filter_by :target_groups, :integer do |arel, target_group_ids|
        arel.joins(:target_groups).where("target_groups.id IN (?)", target_group_ids)
      end

      filter_by :topics, :integer do |arel, topic_ids|
        arel.joins(:topics).where("topics.id IN (?)", topic_ids)
      end
    end

    def index
      @consultings = Consulting.includes(:category).order("title")

      @filter = apply_filter(:consultings) or return
      @consultings = @filter.filter(@consultings)
    end

    def show

    end

  end
end
