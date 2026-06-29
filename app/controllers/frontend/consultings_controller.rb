module Frontend
  class ConsultingsController < ApplicationController

    def index
      redirect_to frontend_offers_path(filter: {scope: "consultings"})
    end

    def show
      offer = Offer.consultings.find_by!(old_id: params[:id])
      redirect_to frontend_offer_path(offer), status: :moved_permanently
    end

  end
end
