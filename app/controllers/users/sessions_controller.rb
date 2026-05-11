module Users
  class SessionsController < Devise::SessionsController
    respond_to :json
    skip_before_action :verify_signed_out_user, only: [:destroy]
    skip_before_action :authenticate_user!, only: [:destroy]

    def destroy
      # Devise-JWT already revoked the token at the Warden middleware level.
      # We just respond with success here.
      render json: { message: "Logged out successfully." }, status: :ok
    end

    private

    def respond_with(resource, _opts = {})
      render json: {
        message: "Logged in successfully.",
        user: user_json(resource)
      }, status: :ok
    end

    def user_json(user)
      { id: user.id, email: user.email }
    end
  end
end
