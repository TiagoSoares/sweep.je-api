module Api
  module V1
    module Auth
      # POST /api/v1/auth/signup — create an organizer account, return a token.
      class RegistrationsController < PublicController
        def create
          user = User.new(registration_params)
          if user.save
            render_authenticated(user, status: :created)
          else
            render_errors(user)
          end
        end

        private

        def registration_params
          params.require(:user).permit(:name, :email, :password)
        end

        def render_authenticated(user, status:)
          token = JsonWebToken.encode({ sub: user.public_id })
          render json: { token:, user: UserSerializer.new(user).serializable_hash }, status:
        end
      end
    end
  end
end
