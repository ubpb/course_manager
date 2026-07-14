module AlmaAuthentication

  extend ActiveSupport::Concern

  private

  def alma_client
    @alma_client ||= AlmaApi::Client.configure do |config|
      config.api_key = ApplicationConfig[:alma_api, :api_key]
    end
  end

  def authenticate_against_alma(user_id, password)
    alma_client.post("users/#{CGI.escape(user_id)}", params: {password: password})
    true
  rescue AlmaApi::LogicalError
    false
  end

  def fetch_alma_user(user_id)
    alma_client.get("users/#{CGI.escape(user_id)}")
  rescue AlmaApi::LogicalError
    nil
  end

end
