class SessionsController < ApplicationController

  include AlmaAuthentication

  layout "frontend"

  # Every attempt checks the given password against Alma, for any active library
  # account, so the form is a password oracle if left unthrottled. There is no
  # local account to lock, which leaves the IP as the only thing to key on.
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { refuse_too_many_attempts }

  before_action { add_breadcrumb t("sessions.new.title"), new_session_path }

  # A page that offers the login, such as a registration form, passes itself as
  # `return_to`. The login leads back there, and so does cancelling it. The page
  # travels in the URL and the form only, never in the session, so a visitor
  # who leaves the login and logs in through the menu later is not taken back
  # to it. A page that required the login stays in the session instead
  # (`authenticate_user!`); cancelling never leads there, as that page would
  # just send the visitor back to the login.
  before_action(only: [:new, :create]) { @offered_by = safe_return_path(params[:return_to]) }

  def new
    redirect_to(@offered_by || account_root_path) if current_user
  end

  def create
    user_id  = params.dig("login", "user_id")
    password = params.dig("login", "password")

    if user_id.present? && password.present?
      if authenticate_against_alma(user_id, password) && (alma_user = get_alma_user(user_id)).present?
        sign_in(User.from_alma_user(alma_user))

        required_by = session.delete(:return_to)
        redirect_to @offered_by || required_by || account_root_path
      else
        flash.now[:error] = t(".failed")
        render :new, status: :unprocessable_content
      end
    else
      redirect_to new_session_path(return_to: @offered_by)
    end
  rescue AlmaApi::Error => e
    log_alma_unavailable(e)
    flash.now[:error] = t(".unavailable")
    render :new, status: :service_unavailable
  end

  # A page that offers the logout passes where to come back to as `return_to`.
  def destroy
    return_to = safe_return_path(params[:return_to])
    sign_out
    redirect_to return_to || root_path, notice: t(".logged_out")
  end

  private

  # Keeps the page that offered the login, so the next attempt still leads back.
  def refuse_too_many_attempts
    redirect_to new_session_path(return_to: safe_return_path(params[:return_to])),
                alert: t("sessions.create.rate_limited")
  end

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
