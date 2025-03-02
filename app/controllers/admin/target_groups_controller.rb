module Admin
  class TargetGroupsController < ApplicationController

    before_action -> { add_breadcrumb "Zielgruppen", admin_target_groups_path }

    def index
      @target_groups = TargetGroup.order(:position)
    end

    def new
      @target_group = TargetGroup.new
    end

    def create
      @target_group = TargetGroup.new(target_group_params)

      if @target_group.save
        respond_to do |format|
          format.html { redirect_to admin_target_groups_path }
          format.turbo_stream do
            render turbo_stream: turbo_stream.refresh(request_id: nil)
          end
        end
      else
        render :new
      end
    end

    def edit
      @target_group = TargetGroup.find(params[:id])
    end

    def update
      @target_group = TargetGroup.find(params[:id])

      if @target_group.update(target_group_params)
        redirect_to admin_target_groups_path
      else
        render :edit
      end
    end

    def destroy
      @target_group = TargetGroup.find(params[:id])
      @target_group.destroy

      respond_to do |format|
        format.html { redirect_to admin_target_groups_path }
        format.turbo_stream do
          render turbo_stream: turbo_stream.refresh(request_id: nil)
        end
      end
    end

    def reorder
      @target_group = TargetGroup.find(params[:id])
      @target_group.insert_at(params.dig(:target_group, :position).to_i)
      head :ok
    end

    private

    def target_group_params
      params.require(:target_group).permit(:title)
    end

  end
end
