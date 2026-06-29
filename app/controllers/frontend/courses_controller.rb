module Frontend
  class CoursesController < ApplicationController

    def index
      redirect_to frontend_offers_path(filter: {scope: "courses"})
    end

    def show
      offer = Offer.courses.find_by!(old_id: params[:id])
      redirect_to frontend_offer_path(offer), status: :moved_permanently
    end

  end
end
