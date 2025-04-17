module Frontend
  class ConsultingsController < ApplicationController

    before_action :prepare_consulting_context

    def index
      redirect_to frontend_offers_path(filter: {scope: "consultings"})
    end

  end
end
