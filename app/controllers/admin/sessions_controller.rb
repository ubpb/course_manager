module Admin
  class SessionsController < ApplicationController

    before_action { add_breadcrumb "Login", new_admin_session_path }

    skip_before_action :authenticate!, only: [:new, :create]

    def new
      redirect_to admin_root_path if current_admin_user
    end

    def create
      user_id  = params.dig("login", "user_id")
      password = params.dig("login", "password")

      if user_id.present? && password.present?
        if authenticate_against_alma(user_id, password) && (alma_user = get_alma_user(user_id)).present?
          alma_primary_id = alma_user["primary_id"]

          session[:current_admin_user_id] = alma_primary_id

          redirect_to admin_root_path
        else
          flash[:error] = "Fehler bei der Anmeldung. Bitte überprüfen Sie Ihre Eingaben."
          render :new, status: :unprocessable_entity
        end
      else
        redirect_to new_admin_session_path
      end
    end

    def destroy
      session[:current_admin_user_id] = nil
      redirect_to(root_path, status: :see_other)
    end

    private

    def alma_client
      @alma_client ||= AlmaApi::Client.configure do |config|
        config.api_key = Rails.application.credentials[:alma_api_key]
      end
    end

    def authenticate_against_alma(user_id, password)
      alma_client.post("users/#{CGI.escape(user_id)}", params: {password: password})
      true
    rescue AlmaApi::LogicalError
      false
    end

    def get_alma_user(user_id)
      alma_user = alma_client.get("users/#{CGI.escape(user_id)}")

      # Make sure only staff users can log in
      return nil unless alma_user.dig("record_type", "value") == "STAFF"
      # Make sure the staff user is active
      return nil unless alma_user.dig("status", "value") == "ACTIVE"

      alma_user
    rescue AlmaApi::LogicalError
      nil
    end

  end
end
