module Admin
  class TargetGroupsController < ApplicationController

    before_action -> { add_breadcrumb "Zielgruppen", admin_target_groups_path }

    def index
      @target_groups = TargetGroup.order(position: :asc)
    end

    def new
      @target_group = TargetGroup.new
      respond_with_modal
    end

    def edit
      @target_group = TargetGroup.find(params.expect(:id))
      respond_with_modal
    end

    def create
      @target_group = TargetGroup.new(target_group_params)

      if @target_group.save
        @target_group.move_to_bottom
        respond_with_list
      else
        respond_with_errors(:new)
      end
    end

    def update
      @target_group = TargetGroup.find(params.expect(:id))

      if @target_group.update(target_group_params)
        respond_with_list
      else
        respond_with_errors(:edit)
      end
    end

    def destroy
      @target_group = TargetGroup.find(params.expect(:id))
      @target_group.destroy
      respond_with_list
    end

    def reorder
      @target_group = TargetGroup.find(params.expect(:id))
      @target_group.insert_at(params.dig(:target_group, :position).to_i)
      head :ok
    end

    private

    def target_group_params
      params.expect(target_group: [:title])
    end

    # The list opens the form in a modal; a visit without Turbo gets it as a page.
    def respond_with_modal
      respond_to do |format|
        format.html
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "target-group-modal", partial: "modal", locals: {target_group: @target_group}
          )
        end
      end
    end

    # Only swap the content of the already open modal — replacing the whole
    # container would spawn a second modal on top of it.
    def respond_with_errors(template)
      respond_to do |format|
        format.html { render template, status: :unprocessable_content }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "target-group-form", partial: "form", locals: {target_group: @target_group}
          ), status: :unprocessable_content
        end
      end
    end

    # The refresh morphs the list into its new state, which also closes the modal.
    def respond_with_list
      respond_to do |format|
        format.html { redirect_to admin_target_groups_path }
        format.turbo_stream { render turbo_stream: turbo_stream.refresh(request_id: nil) }
      end
    end

  end
end
