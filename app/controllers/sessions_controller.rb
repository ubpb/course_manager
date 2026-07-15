class SessionsController < ApplicationController

  include AlmaAuthentication

  layout "frontend"

  before_action { add_breadcrumb t("sessions.new.title"), new_session_path }

  def new
    redirect_to account_root_path if current_user
  end

  def create
    user_id  = params.dig("login", "user_id")
    password = params.dig("login", "password")

    if user_id.present? && password.present?
      if authenticate_against_alma(user_id, password) && (alma_user = get_alma_user(user_id)).present?
        sign_in(User.from_alma_user(alma_user))

        redirect_to session.delete(:return_to) || account_root_path
      else
        flash.now[:error] = t("sessions.create.failed")
        render :new, status: :unprocessable_entity
      end
    else
      redirect_to new_session_path
    end
  end

  def destroy
    sign_out
    redirect_to root_path, notice: t("sessions.destroy.logged_out")
  end

  private

  # Unlike the admin login every active Alma user may log in,
  # not just staff users.
  def get_alma_user(user_id)
    alma_user = fetch_alma_user(user_id)
    return nil if alma_user.nil?

    # Make sure the user is active
    return nil unless alma_user.dig("status", "value") == "ACTIVE"

    alma_user
  end

end
