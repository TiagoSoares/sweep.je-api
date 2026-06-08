module Api
  module V1
    module Public
      # Unauthenticated share-page endpoints (§4.2). Access is gated by the
      # sweepstake's share_token; participants identify themselves with a
      # per-sweepstake claim_token, not an account.
      class SharesController < PublicController
        before_action :set_sweepstake

        # GET /api/v1/s/:share_token
        def show
          render json: { sweepstake: PublicSweepstakeSerializer.new(@sweepstake).serializable_hash }
        end

        # POST /api/v1/s/:share_token/register  { participant: { name }, quantity }
        #
        # `quantity` lets a person hold several entries in the draw, but only when
        # the organizer allowed multiple entries — otherwise it's forced to 1. It's
        # clamped to the per-registration cap and to the free entry slots left, so
        # the total entries never exceed the team count (everyone gets at least one).
        def register
          unless @sweepstake.accepting_registrations?
            return render_error(status: :conflict, code: "registration_closed",
                                detail: registration_closed_reason)
          end

          participant = @sweepstake.participants.new(
            name: params.dig(:participant, :name).to_s.strip,
            entries_count: effective_quantity,
            registered_ip: request.remote_ip,
            user_agent: request.user_agent
          )
          # Filtered to the sweepstake's known questions by the model setter.
          participant.predictions = predictions_param

          if participant.save
            render json: {
              claim_token: participant.claim_token,
              count: participant.entries_count,
              participant: ParticipantSerializer.new(participant).serializable_hash
            }, status: :created
          else
            render_errors(participant)
          end
        end

        # GET /api/v1/s/:share_token/me?claim_token=...
        # The caller's own registration plus their assigned entries once drawn.
        def me
          claim_token = params[:claim_token].to_s
          participant = claim_token.present? && @sweepstake.participants.find_by(claim_token:)
          return render_not_found unless participant

          render json: {
            participant: ParticipantSerializer.new(participant).serializable_hash,
            entries: DrawResults.entries_for(participant)
          }
        end

        # GET /api/v1/s/:share_token/results — all allocations (nil until drawn).
        def results
          render json: { results: DrawResults.results_for(@sweepstake) }
        end

        # GET /api/v1/s/:share_token/verification — seed + orderings to reproduce
        # the draw independently (§4.4).
        def verification
          render json: { verification: DrawResults.verification_for(@sweepstake) }
        end

        private

        def set_sweepstake
          @sweepstake = Sweepstake.includes(:user, :participants, :entries)
                                  .find_by!(share_token: params[:share_token])
        end

        # How many entries this registration claims. Always 1 unless the organizer
        # allowed multiple entries; then clamped to the per-registration cap and to
        # the free entry slots left (so totals never exceed the team count). At
        # least 1 — accepting_registrations? guarantees a slot is free.
        def effective_quantity
          max_per_reg = @sweepstake.allow_multiple_entries ? Sweepstake::MAX_ENTRIES_PER_REGISTRATION : 1
          remaining = @sweepstake.remaining_entries
          cap = remaining ? [max_per_reg, remaining].min : max_per_reg

          requested = @sweepstake.allow_multiple_entries ? (params[:quantity] || params.dig(:participant, :quantity)).to_i : 1
          requested = 1 if requested < 1
          [requested, cap].min
        end

        # Raw { label => guess } map. Safe to take unfiltered: the model setter
        # keeps only the sweepstake's known question labels.
        def predictions_param
          raw = params.dig(:participant, :predictions)
          raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw
        end

        def registration_closed_reason
          if @sweepstake.full?
            "This sweepstake is full"
          else
            "Registration is closed"
          end
        end
      end
    end
  end
end
