module Admin
  class TopicsController < ApplicationController

    before_action -> { add_breadcrumb "Themen", admin_topics_path }

    def index
      @topics = Topic.order(position: :asc)
    end

    def new
      @topic = Topic.new
      respond_with_modal
    end

    def edit
      @topic = Topic.find(params.expect(:id))
      respond_with_modal
    end

    def create
      @topic = Topic.new(topic_params)

      if @topic.save
        @topic.move_to_bottom
        respond_with_list
      else
        respond_with_errors(:new)
      end
    end

    def update
      @topic = Topic.find(params.expect(:id))

      if @topic.update(topic_params)
        respond_with_list
      else
        respond_with_errors(:edit)
      end
    end

    def destroy
      @topic = Topic.find(params.expect(:id))
      @topic.destroy
      respond_with_list
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

    # The list opens the form in a modal; a visit without Turbo gets it as a page.
    def respond_with_modal
      respond_to do |format|
        format.html
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("topic-modal", partial: "modal", locals: {topic: @topic})
        end
      end
    end

    # Only swap the content of the already open modal — replacing the whole
    # container would spawn a second modal on top of it.
    def respond_with_errors(template)
      respond_to do |format|
        format.html { render template, status: :unprocessable_content }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("topic-form", partial: "form", locals: {topic: @topic}),
                 status: :unprocessable_content
        end
      end
    end

    # The refresh morphs the list into its new state, which also closes the modal.
    def respond_with_list
      respond_to do |format|
        format.html { redirect_to admin_topics_path }
        format.turbo_stream { render turbo_stream: turbo_stream.refresh(request_id: nil) }
      end
    end

  end
end
