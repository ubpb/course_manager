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

  # Any other AlmaApi::Error means Alma could not answer at all: it is down,
  # overloaded or refuses the API key. The login forms say so instead of
  # failing; the log keeps the cause. For a network error the client raises a
  # bare AlmaApi::Error with a fixed message, the real error is its cause.
  def log_alma_unavailable(error)
    cause = " (#{error.cause.class}: #{error.cause.message})" if error.cause
    Rails.logger.error("Alma is unavailable for the login: #{error.class}: #{error.message}#{cause}")
  end

end
