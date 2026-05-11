module Users
  class RegistrationsController < Devise::RegistrationsController
    respond_to :json

    private

    def respond_with(resource, _opts = {})
      if resource.persisted?
        render json: {
          message: "Signed up successfully.",
          user: user_json(resource)
        }, status: :created
      else
        render json: {
          message: "Sign up failed.",
          errors: resource.errors.full_messages
        }, status: :unprocessable_entity
      end
    end

    def user_json(user)
      { id: user.id, email: user.email }
    end
  end
end
