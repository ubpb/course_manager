module Admin
  class TargetGroupsController < ApplicationController

    include ModalForm

    before_action -> { add_breadcrumb "Zielgruppen", admin_target_groups_path }

    def index
      @target_groups = TargetGroup.order(position: :asc)
    end

    def new
      @target_group = TargetGroup.new
      respond_with_modal(target_group: @target_group)
    end

    def edit
      @target_group = TargetGroup.find(params.expect(:id))
      respond_with_modal(target_group: @target_group)
    end

    def create
      @target_group = TargetGroup.new(target_group_params)

      if @target_group.save
        @target_group.move_to_bottom
        respond_with_list(admin_target_groups_path)
      else
        respond_with_errors(:new, target_group: @target_group)
      end
    end

    def update
      @target_group = TargetGroup.find(params.expect(:id))

      if @target_group.update(target_group_params)
        respond_with_list(admin_target_groups_path)
      else
        respond_with_errors(:edit, target_group: @target_group)
      end
    end

    def destroy
      @target_group = TargetGroup.find(params.expect(:id))
      @target_group.destroy
      respond_with_list(admin_target_groups_path)
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

  end
end
