module Admin
  class TopicsController < ApplicationController

    before_action -> { add_breadcrumb "Themen", admin_topics_path }

    def index
      @topics = Topic.order(position: :asc)
    end

    def new
      @topic = Topic.new
    end

    def create
      @topic = Topic.new(topic_params)

      if @topic.save
        @topic.move_to_bottom

        if turbo_frame_request? && request.format == :turbo_stream
          render turbo_stream: turbo_stream.refresh(request_id: nil)
        else
          redirect_to admin_topics_path
        end
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @topic = Topic.find(params[:id])
    end

    def update
      @topic = Topic.find(params[:id])

      if @topic.update(topic_params)
        redirect_to admin_topics_path
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @topic = Topic.find(params[:id])
      @topic.destroy

      respond_to do |format|
        format.html { redirect_to admin_topics_path }
        format.turbo_stream do
          render turbo_stream: turbo_stream.refresh(request_id: nil)
        end
      end
    end

    def reorder
      @topic = Topic.find(params[:id])
      @topic.insert_at(params.dig(:topic, :position).to_i)
      head :ok
    end

    private

    def topic_params
      params.require(:topic).permit(:title)
    end

  end
end
