module Admin
  class CategoriesController < ApplicationController

    before_action -> { add_breadcrumb "Kategorien", admin_categories_path }

    def index
      @categories = Category.order(position: :asc)
    end

    def new
      @category = Category.new
    end

    def create
      @category = Category.new(category_params)

      if @category.save
        @category.move_to_bottom

        if turbo_frame_request? && request.format == :turbo_stream
          render turbo_stream: turbo_stream.refresh(request_id: nil)
        else
          redirect_to admin_categories_path
        end
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @category = Category.find(params[:id])
    end

    def update
      @category = Category.find(params[:id])

      if @category.update(category_params)
        redirect_to admin_categories_path
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @category = Category.find(params[:id])
      @category.destroy

      respond_to do |format|
        format.html { redirect_to admin_categories_path }
        format.turbo_stream do
          render turbo_stream: turbo_stream.refresh(request_id: nil)
        end
      end
    end

    def reorder
      @category = Category.find(params[:id])
      @category.insert_at(params.dig(:category, :position).to_i)
      head :ok
    end

    private

    def category_params
      params.require(:category).permit(:title, :color_code)
    end

  end
end
