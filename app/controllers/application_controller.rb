class ApplicationController < ActionController::API
  before_action :authenticate_user!

  private

  def render_unauthorized
    render json: { error: "Unauthorized" }, status: :unauthorized
  end
end
