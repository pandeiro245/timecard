class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  helper_method :timer

  def timer
    return "" unless user_signed_in?
    current_user.work_logs.running? ? current_user.work_logs.running.start_at.to_s(:rfc822) : ""
  end
end
