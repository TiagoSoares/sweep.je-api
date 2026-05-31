module Api
  module V1
    # Organizer management of registrants (§8). Participant self-registration is
    # handled by the public Shares controller.
    class ParticipantsController < BaseController
      # GET /api/v1/sweepstakes/:sweepstake_id/participants
      def index
        sweepstake = current_user.sweepstakes.find_by_public_id!(params[:sweepstake_id])
        authorize sweepstake, :show?
        render json: { participants: ParticipantSerializer.new(sweepstake.participants).serializable_hash }
      end

      # DELETE /api/v1/participants/:id
      def destroy
        participant = Participant.find_by_public_id!(params[:id])
        authorize participant
        participant.destroy
        head :no_content
      end
    end
  end
end
