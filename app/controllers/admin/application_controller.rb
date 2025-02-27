module Admin
  class ApplicationController < ::ApplicationController

    before_action -> { add_breadcrumb("Admin", admin_root_path) }
    before_action :authenticate!

    layout "admin"

    private

    def authenticate!
      if current_admin_user
        true
      else
        redirect_to(new_admin_session_path)
        false
      end
    end

    def current_admin_user
      @current_admin_user ||= if (user_id = session[:current_admin_user_id])
        user_id
      end
    end
    helper_method :current_admin_user

    def raise_if_action_is_inherited
      action_is_implemented = self.class.instance_method(action_name).owner == self.class

      if respond_to?(action_name) && !action_is_implemented
        raise NotImplementedError, "Action #{action_name} is not implemented in #{self.class}"
      end
    end

  end
end
