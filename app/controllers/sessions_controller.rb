class SessionsController < ApplicationController

  include AlmaAuthentication

  layout "frontend"

  # Every attempt checks the given password against Alma, for any active library
  # account, so the form is a password oracle if left unthrottled. There is no
  # local account to lock, which leaves the IP as the only thing to key on.
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_session_path, alert: t("sessions.create.rate_limited") }

  before_action { add_breadcrumb t("sessions.new.title"), new_session_path }

  # A page that offers the login, such as a registration form, passes where to
  # come back to as `return_to`. Cancelling the login leads back there, and only
  # there: the page that a login was required for would just send the visitor
  # back to the login. The form carries it on, so it outlasts a failed attempt.
  before_action(only: [:new, :create]) { @offered_by = safe_return_path(params[:return_to]) }

  def new
    return redirect_to(@offered_by || account_root_path) if current_user

    session[:return_to] = @offered_by if @offered_by
  end

  def create
    user_id  = params.dig("login", "user_id")
    password = params.dig("login", "password")

    if user_id.present? && password.present?
      if authenticate_against_alma(user_id, password) && (alma_user = get_alma_user(user_id)).present?
        sign_in(User.from_alma_user(alma_user))

        redirect_to session.delete(:return_to) || account_root_path
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
