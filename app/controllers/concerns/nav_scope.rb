module NavScope

  extend ActiveSupport::Concern

  included do
    before_action -> { @nav_scope = params[:nav_scope].presence }
    helper_method :nav_scope
  end

  private

  def nav_scope
    @nav_scope
  end

  def default_url_options
    nav_scope ? super.merge({nav_scope: nav_scope}) : super
  end

end
