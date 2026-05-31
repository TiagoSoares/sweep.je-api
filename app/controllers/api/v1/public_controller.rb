module Api
  module V1
    # Base for unauthenticated public endpoints (auth + share/participant routes).
    # No `authenticate_user!`; access to a sweepstake is gated by its share_token.
    class PublicController < ApplicationController
    end
  end
end
