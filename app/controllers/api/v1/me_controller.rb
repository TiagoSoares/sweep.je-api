module Api
  module V1
    # GET /api/v1/me — the authenticated user's profile.
    class MeController < BaseController
      def show
        render json: { user: UserSerializer.new(current_user).serializable_hash }
      end
    end
  end
end
