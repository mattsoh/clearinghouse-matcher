class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :require_login!

  rescue_from Hcb::TokenExpiredError do
    reset_session
    redirect_to login_path, alert: "Your session with HCB expired. Please log in again."
  end

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end
  helper_method :current_user

  def require_login!
    redirect_to login_path unless current_user
  end

  def hcb_client
    @hcb_client ||= Hcb::Client.new(current_user)
  end
end
