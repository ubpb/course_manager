module NavScope

  extend ActiveSupport::Concern

  # Marks an event opened from the events of its offer. Without a nav_scope an
  # event belongs to the global event list.
  OFFER = "offer".freeze

  included do
    before_action -> { @nav_scope = params[:nav_scope].presence }
    helper_method :nav_scope, :offer_context?
  end

  private

  def nav_scope
    @nav_scope
  end

  def offer_context?
    nav_scope == OFFER
  end

  def default_url_options
    nav_scope ? super.merge({nav_scope: nav_scope}) : super
  end

end
