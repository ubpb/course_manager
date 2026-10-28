module Admin
  class TopicsController < ApplicationController

    include ModalForm

    before_action -> { add_breadcrumb "Themen", admin_topics_path }

    def index
      @topics = Topic.order(position: :asc)
    end

    def new
      @topic = Topic.new
      respond_with_modal(topic: @topic)
    end

    def edit
      @topic = Topic.find(params.expect(:id))
      respond_with_modal(topic: @topic)
    end

    def create
      @topic = Topic.new(topic_params)

      if @topic.save
        @topic.move_to_bottom
        respond_with_list(admin_topics_path)
      else
        respond_with_errors(:new, topic: @topic)
      end
    end

    def update
      @topic = Topic.find(params.expect(:id))

      if @topic.update(topic_params)
        respond_with_list(admin_topics_path)
      else
        respond_with_errors(:edit, topic: @topic)
      end
    end

    def destroy
      @topic = Topic.find(params.expect(:id))
      @topic.destroy
      respond_with_list(admin_topics_path)
    end

    def reorder
      @topic = Topic.find(params.expect(:id))
      @topic.insert_at(params.dig(:topic, :position).to_i)
      head :ok
    end

    private

    def topic_params
      params.expect(topic: [:title])
    end

  end
end
