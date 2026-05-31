module Api
  module V1
    # Base for all authenticated organizer/admin endpoints. Reads a Bearer token,
    # resolves `current_user`, and rejects unauthenticated requests by default.
    class BaseController < ApplicationController
      before_action :authenticate_user!

      attr_reader :current_user

      private

      def authenticate_user!
        @current_user = authenticate_from_token
        return if @current_user

        render_error(status: :unauthorized, code: "unauthorized", detail: "Authentication required")
      end

      def authenticate_from_token
        header = request.headers["Authorization"]
        return nil unless header&.start_with?("Bearer ")

        payload = JsonWebToken.decode(header.split(" ", 2).last)
        return nil unless payload

        User.find_by(public_id: payload[:sub])
      end

      # Pundit asks for `pundit_user`; ours is the token-resolved user.
      def pundit_user
        current_user
      end
    end
  end
end
