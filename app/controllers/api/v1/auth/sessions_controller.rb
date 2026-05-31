module Api
  module V1
    module Auth
      # POST   /api/v1/auth/login  — exchange email+password for a token.
      # DELETE /api/v1/auth/logout — stateless; client discards the token.
      class SessionsController < PublicController
        def create
          user = User.find_by(email: params.dig(:user, :email).to_s.strip.downcase)
          if user&.authenticate(params.dig(:user, :password))
            token = JsonWebToken.encode({ sub: user.public_id })
            render json: { token:, user: UserSerializer.new(user).serializable_hash }
          else
            render_error(status: :unauthorized, code: "invalid_credentials",
                         detail: "Invalid email or password")
          end
        end

        # Tokens are stateless (no server-side session to revoke in v1). A future
        # phase can add a denylist / token versioning if revocation is required.
        def destroy
          head :no_content
        end
      end
    end
  end
end
