module Frontend
  class PagesController < ApplicationController

    before_action -> { add_breadcrumb t("frontend.pages.#{action_name}.title") }, except: [:home] # rubocop:disable Rails/LexicallyScopedActionFilter

  end
end
