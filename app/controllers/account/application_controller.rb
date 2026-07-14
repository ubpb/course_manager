module Account
  class ApplicationController < ::ApplicationController

    layout "frontend"

    before_action :authenticate_user!
    before_action { add_breadcrumb t("account.title"), account_root_path }

  end
end
