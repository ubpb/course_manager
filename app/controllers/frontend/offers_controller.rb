module Frontend
  class OffersController < ApplicationController

    def index
      courses = Course.published.order(title: :asc).distinct
      consultings = Consulting.includes(:category).order("title")

      @offers = courses.to_a + consultings.to_a
    end

  end
end
