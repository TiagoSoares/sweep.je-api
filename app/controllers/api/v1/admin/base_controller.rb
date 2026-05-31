module Api
  module V1
    module Admin
      # Base for platform-admin endpoints. Requires an authenticated admin user.
      class BaseController < Api::V1::BaseController
        before_action :require_admin!

        private

        def require_admin!
          return if current_user&.admin?

          render_error(status: :forbidden, code: "forbidden", detail: "Admin access required")
        end
      end
    end
  end
end
