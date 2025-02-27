module ReturnPath

  extend ActiveSupport::Concern

  included do
    helper_method :return_path
  end

  class Error < StandardError; end
  class RequiredError < Error; end

  private

  def require_return_path
    @return_path = sanitize_return_path(params[:return_path])
    raise RequiredError if @return_path.blank?
  end

  def return_path
    @return_path
  end

  def sanitize_return_path(return_path, query: true, fragment: true)
    if return_path.present?
      return_path = URI(return_path)

      path = return_path.path.present? ? return_path.path.to_s : ""
      query = query && return_path.query.present? ? "?#{return_path.query}" : ""
      fragment = fragment && return_path.fragment.present? ? "##{return_path.fragment}" : ""

      (path + query + fragment).presence
    end
  rescue StandardError
    nil
  end

end
